import Foundation
import MLX
import Qwen3ASR

/// 原生 ASR 引擎，使用 qwen3-asr-swift 进行本地语音识别
final class NativeASREngine: ASRBackend {

    // MARK: - 常量 - 统一的模型缓存目录

    /// 模型缓存目录 - 统一使用 qwen3-speech
    /// 这是 qwen3-asr-swift 库的默认缓存目录
    static let modelCacheDirectory: URL = {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        return homeDir.appendingPathComponent("Library/Caches/qwen3-speech")
    }()

    // MARK: - ASRBackend 回调

    var onTranscriptionResult: ((String) -> Void)?
    var onPartialResult: ((String, String) -> Void)?
    var onPolishUpdate: ((String) -> Void)?
    var onConnectionStatusChanged: ((Bool) -> Void)?
    var onErrorStateChanged: ((Bool, String?) -> Void)?
    var onOriginalTextReceived: ((String) -> Void)?
    var onPolishMethodReceived: ((String) -> Void)?

    // MARK: - 模型状态

    enum ModelState {
        case notDownloaded  // 模型未下载
        case notLoaded      // 模型已下载但未加载到内存
        case loading(progress: String)
        case loaded
        case failed(Error)
    }

    private(set) var modelState: ModelState = .notLoaded
    private var model: Qwen3ASR.Qwen3ASRModel?
    private var currentModelId: NativeModelID?

    // MARK: - 模型检测

    /// 检测指定模型是否已下载
    /// 检查模型文件（.safetensors 或 .bin）是否存在于缓存目录
    func isModelDownloaded(_ modelId: NativeModelID) -> Bool {
        let modelDir = Self.modelCacheDirectory
            .appendingPathComponent(modelId.rawValue.replacingOccurrences(of: "/", with: "_"))

        NSLog("[NativeASR] Checking model: %@", modelId.rawValue)
        NSLog("[NativeASR] Cache path: %@", modelDir.path)

        // 检查目录是否存在
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelDir.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            NSLog("[NativeASR] Model directory not found")
            return false
        }

        // 检查是否包含模型文件
        let contents = try? FileManager.default.contentsOfDirectory(atPath: modelDir.path)
        let hasModelFiles = contents?.contains(where: { $0.hasSuffix(".safetensors") || $0.hasSuffix(".bin") }) ?? false

        NSLog("[NativeASR] Directory contents: %@", contents?.joined(separator: ", ") ?? "empty")
        NSLog("[NativeASR] Has model files: %@", hasModelFiles ? "YES" : "NO")

        return hasModelFiles
    }

    /// 是否已加载模型并就绪
    var isReady: Bool {
        if case .loaded = modelState { return true }
        return false
    }

    var isModelLoaded: Bool { isReady }

    var modelLoadProgress: String {
        if case .loading(let progress) = modelState { return progress }
        return ""
    }

    /// 当前选中的模型是否已下载
    var isCurrentModelDownloaded: Bool {
        let modelId = currentModelId ?? SettingsManager.shared.nativeModelId
        return isModelDownloaded(modelId)
    }

    // MARK: - 录音状态

    private var isSessionActive = false
    private var currentConfig: ASRSessionConfig?
    private var audioBuffer: [Float] = []
    private let audioLock = NSLock()

    // 实时预览定时器
    private var previewTimer: Timer?
    private let previewInterval: TimeInterval = 0.5
    private let previewWindowSize: Int = 4 * 16000
    private var lastPreviewTime: Date = .distantPast
    private var hasAudioData: Bool = false

    // 字幕模式定时转录
    private var subtitleTimer: Timer?
    private let subtitleInterval: TimeInterval = 1.5
    private let subtitleWindowSize: Int = 6 * 16000

    // MARK: - 润色

    private let textPolisher = TextPolisher.shared
    private let llmPolisher = LLMPolisher.shared

    // MARK: - ASRBackend 协议实现

    func connect() {
        // Native 模式下 connect = 加载模型（仅在未加载时）
        if !isReady {
            Task {
                await loadModel(forceReload: false)
            }
        }
    }

    func disconnect() {
        stopPreviewTimer()
        stopSubtitleTimer()
        resetVADState()
        isSessionActive = false
        audioLock.lock()
        audioBuffer.removeAll()
        audioLock.unlock()
    }

    func startSession(config: ASRSessionConfig, completion: @escaping () -> Void) {
        guard isReady, let model = self.model else {
            NSLog("[NativeASR] Cannot start session: model not loaded")
            completion()
            return
        }

        isSessionActive = true
        currentConfig = config
        resetVADState()

        audioLock.lock()
        audioBuffer.removeAll()
        audioLock.unlock()

        if config.mode == .voiceInput {
            startPreviewTimer()
        } else {
            startSubtitleTimer()
        }

        NSLog("[NativeASR] Session started: mode=%@, language=%@", config.mode.rawValue, config.language.rawValue)
        completion()
    }

    func stopSession(completion: @escaping () -> Void) {
        stopPreviewTimer()
        stopSubtitleTimer()

        guard isSessionActive else {
            completion()
            return
        }

        isSessionActive = false
        let config = currentConfig

        audioLock.lock()
        let finalAudio = audioBuffer
        audioBuffer.removeAll()
        audioLock.unlock()

        // 最少需要 0.5 秒音频 (16kHz * 0.5s = 8000 样本)，否则 MLX 数组索引可能越界崩溃
        let minSamples = 8000
        guard finalAudio.count >= minSamples, let model = self.model else {
            NSLog("[NativeASR] Audio too short (%d samples, need %d) or model nil, skipping", finalAudio.count, minSamples)
            DispatchQueue.main.async { [weak self] in
                self?.onTranscriptionResult?("")
            }
            completion()
            return
        }

        Task.detached { [weak self] in
            guard let self = self else { return }
            do {
                let text = try withError {
                    model.transcribe(audio: finalAudio, sampleRate: 16000)
                }
                self.processFinalResult(text: text, config: config, completion: completion)
            } catch {
                NSLog("[NativeASR] Transcription error: %@", error.localizedDescription)
                DispatchQueue.main.async { [weak self] in
                    self?.onTranscriptionResult?("")
                    self?.onErrorStateChanged?(true, "转录失败: \(error.localizedDescription)")
                }
                completion()
            }
        }
    }

    /// 处理最终转录结果
    private func processFinalResult(text: String, config: ASRSessionConfig?, completion: @escaping () -> Void) {
        NSLog("[NativeASR] Final transcription: %@", text)

        var processedText = text
        let originalText = text
        var polishMethod = "none"

        if config?.enablePolish == true {
            processedText = self.textPolisher.polish(processedText)
            processedText = self.textPolisher.detectAndCorrect(processedText)
            polishMethod = "rules"
        }

        DispatchQueue.main.async { [weak self] in
            self?.onOriginalTextReceived?(originalText)
            self?.onPolishMethodReceived?(polishMethod)
            self?.onTranscriptionResult?(processedText)
        }

        if config?.useLLMPolish == true {
            Task.detached { [weak self] in
                guard let self = self else { return }
                let sceneInfo = config?.scene
                let llmSettings = SettingsManager.shared.llmSettings
                let (polished, method) = await self.llmPolisher.polishAsync(
                    text: originalText,
                    scene: sceneInfo,
                    useLLM: true,
                    llmSettings: llmSettings
                )
                if method == "llm" && polished != processedText {
                    DispatchQueue.main.async { [weak self] in
                        self?.onPolishUpdate?(polished)
                    }
                }
            }
        }

        completion()
    }

    func feedAudioChunk(_ data: Data) {
        guard isSessionActive else { return }

        let samples = parseAudioData(data)
        guard !samples.isEmpty else { return }

        if currentConfig?.mode == .voiceInput {
            processAudioWithVAD(samples)
        } else {
            audioLock.lock()
            audioBuffer.append(contentsOf: samples)
            audioLock.unlock()
        }
    }

    func flushAndStop(completion: @escaping () -> Void) {
        stopSession(completion: completion)
    }

    // MARK: - 实时预览

    private func processAudioWithVAD(_ samples: [Float]) {
        let energy = calculateEnergy(samples)
        let isSpeech = energy > 0.01

        if isSpeech {
            hasAudioData = true
        }

        audioLock.lock()
        audioBuffer.append(contentsOf: samples)
        audioLock.unlock()
    }

    private func startPreviewTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.previewTimer = Timer.scheduledTimer(withTimeInterval: self.previewInterval, repeats: true) { [weak self] _ in
                self?.performPreview()
            }
        }
    }

    private func stopPreviewTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.previewTimer?.invalidate()
            self?.previewTimer = nil
        }
    }

    private func performPreview() {
        guard isSessionActive, hasAudioData, let model = self.model else { return }

        audioLock.lock()
        guard audioBuffer.count > previewWindowSize else {
            audioLock.unlock()
            return
        }
        let windowStart = max(0, audioBuffer.count - previewWindowSize)
        let previewAudio = Array(audioBuffer[windowStart...])
        audioLock.unlock()

        Task.detached { [weak self] in
            do {
                let text = try withError {
                    model.transcribe(audio: previewAudio, sampleRate: 16000)
                }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

                NSLog("[NativeASR] Preview: %@", text)
                DispatchQueue.main.async {
                    self?.onPartialResult?(text, "preview")
                }
            } catch {
                NSLog("[NativeASR] Preview transcription error: %@", error.localizedDescription)
            }
        }
    }

    private func calculateEnergy(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        return sqrt(sum / Float(samples.count))
    }

    private func resetVADState() {
        hasAudioData = false
        lastPreviewTime = .distantPast
    }

    // MARK: - 字幕模式

    private func startSubtitleTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.subtitleTimer = Timer.scheduledTimer(withTimeInterval: self.subtitleInterval, repeats: true) { [weak self] _ in
                self?.performPeriodicTranscription()
            }
        }
    }

    private func performPeriodicTranscription() {
        guard isSessionActive, let model = self.model else { return }

        audioLock.lock()
        let minSamples = 8000
        guard audioBuffer.count >= minSamples else {
            audioLock.unlock()
            return
        }

        let windowStart = max(0, audioBuffer.count - subtitleWindowSize)
        let windowAudio = Array(audioBuffer[windowStart...])
        audioLock.unlock()

        Task.detached { [weak self] in
            do {
                let text = try withError {
                    model.transcribe(audio: windowAudio, sampleRate: 16000)
                }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

                DispatchQueue.main.async {
                    self?.onPartialResult?(text, "periodic")
                }
            } catch {
                NSLog("[NativeASR] Periodic transcription error: %@", error.localizedDescription)
            }
        }
    }

    private func stopSubtitleTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.subtitleTimer?.invalidate()
            self?.subtitleTimer = nil
        }
    }

    // MARK: - 模型管理

    /// 加载 ASR 模型
    /// - Parameters:
    ///   - modelId: 要加载的模型ID，默认使用设置中的选择
    ///   - forceReload: 是否强制重新加载
    func loadModel(modelId: NativeModelID? = nil, forceReload: Bool = false) async {
        let targetModelId = modelId ?? SettingsManager.shared.nativeModelId
        NSLog("[NativeASR] loadModel: target=%@, current=%@, forceReload=%@",
              targetModelId.rawValue, currentModelId?.rawValue ?? "nil", forceReload ? "true" : "false")

        // 已加载相同模型则跳过
        if !forceReload && isReady && currentModelId == targetModelId {
            NSLog("[NativeASR] Same model already loaded")
            return
        }

        // 如果已加载其他模型，先卸载
        if isReady && currentModelId != nil && currentModelId != targetModelId {
            NSLog("[NativeASR] Switching model, unloading current")
            model = nil
            currentModelId = nil
            modelState = .notLoaded
        }

        // 检查模型是否已下载（forceReload 时跳过检查，直接尝试加载）
        let downloaded = isModelDownloaded(targetModelId)
        if !forceReload && !downloaded {
            modelState = .notDownloaded
            NSLog("[NativeASR] Model not downloaded")
            DispatchQueue.main.async { [weak self] in
                self?.onErrorStateChanged?(true, "模型未下载，请点击下载按钮下载模型")
            }
            return
        }

        // 加载模型
        modelState = .loading(progress: "正在加载模型...")
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStatusChanged?(false)
        }

        NSLog("[NativeASR] Starting model load...")

        do {
            let loadedModel = try await Qwen3ASR.Qwen3ASRModel.fromPretrained(modelId: targetModelId.rawValue)

            model = loadedModel
            currentModelId = targetModelId
            modelState = .loaded

            NSLog("[NativeASR] Model loaded successfully!")

            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(true)
                self?.onErrorStateChanged?(false, nil)
            }
        } catch {
            modelState = .failed(error)
            NSLog("[NativeASR] Model loading failed: %@", error.localizedDescription)

            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(false)
                self?.onErrorStateChanged?(true, "模型加载失败: \(error.localizedDescription)")
            }
        }
    }

    /// 下载模型（通过加载触发自动下载）
    func downloadModel(modelId: NativeModelID? = nil) async -> Bool {
        let targetModelId = modelId ?? SettingsManager.shared.nativeModelId

        if isModelDownloaded(targetModelId) {
            NSLog("[NativeASR] Model already downloaded")
            return true
        }

        modelState = .loading(progress: "正在下载模型...")
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStatusChanged?(false)
        }

        NSLog("[NativeASR] Downloading model...")

        do {
            let loadedModel = try await Qwen3ASR.Qwen3ASRModel.fromPretrained(modelId: targetModelId.rawValue)

            model = loadedModel
            currentModelId = targetModelId
            modelState = .loaded

            NSLog("[NativeASR] Model downloaded and loaded")

            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(true)
                self?.onErrorStateChanged?(false, nil)
            }
            return true
        } catch {
            modelState = .failed(error)
            NSLog("[NativeASR] Model download failed: %@", error.localizedDescription)

            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(false)
                self?.onErrorStateChanged?(true, "模型下载失败: \(error.localizedDescription)")
            }
            return false
        }
    }

    /// 卸载模型释放内存
    func unloadModel() {
        model = nil
        currentModelId = nil
        modelState = .notLoaded
        DispatchQueue.main.async { [weak self] in
            self?.onConnectionStatusChanged?(false)
        }
    }

    // MARK: - 音频解析

    private func parseAudioData(_ data: Data) -> [Float] {
        guard data.count > 1 else { return [] }

        let formatByte = data[0]
        let audioData = data.dropFirst()

        switch formatByte {
        case 0x02:
            return audioData.withUnsafeBytes { ptr in
                let int16Ptr = ptr.bindMemory(to: Int16.self)
                return int16Ptr.map { Float($0) / 32767.0 }
            }
        case 0x01:
            return audioData.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }
        default:
            return data.withUnsafeBytes { ptr in
                Array(ptr.bindMemory(to: Float.self))
            }
        }
    }
}
