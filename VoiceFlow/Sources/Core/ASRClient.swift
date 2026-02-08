import Foundation
import AppKit

private enum ASRMessageType: String, Decodable {
    case final
    case partial
    case polish_update  // LLM 润色完成后的更新
    case config_llm_ack
    case test_llm_connection_result
    case analysis_result
}

private struct ASRMessage: Decodable {
    let type: ASRMessageType
    let text: String
    let original_text: String?
    let polish_method: String?  // LLM 润色方法: "llm", "rules", "none"
}

final class ASRClient {
    var onTranscriptionResult: ((String) -> Void)?
    var onPartialResult: ((String, String) -> Void)?  // 实时部分结果回调 (text, trigger: "pause"/"periodic")
    var onOriginalTextReceived: ((String) -> Void)?  // 原始文本回调
    var onPolishMethodReceived: ((String) -> Void)?  // 润色方法回调
    var onPolishUpdate: ((String) -> Void)?  // LLM 润色更新回调
    var onConnectionStatusChanged: ((Bool) -> Void)?
    var onErrorStateChanged: ((Bool, String?) -> Void)?
    var onLLMConnectionTestResult: ((Bool, Int?) -> Void)?  // LLM 连接测试结果
    var onHistoryAnalysisResult: ((HistoryAnalysisResult?) -> Void)?  // 历史分析结果
    var onDefaultPromptsReceived: (([String: String]) -> Void)?  // 默认提示词回调
    var onCustomPromptsReceived: (([String: String]) -> Void)?  // 自定义提示词回调
    var onPromptSaved: ((String, Bool) -> Void)?  // 提示词保存结果 (sceneType, success)

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession = URLSession(configuration: .default)
    private var reconnectTask: Task<Void, Never>?
    private let serverURL = URL(string: "ws://localhost:9876")!
    private var isConnected = false

    /// 公开的连接状态（供外部检查 ASR 服务器是否可用）
    var isServerConnected: Bool { isConnected }

    // 追踪待发送的音频块数量
    private var pendingAudioSends = 0
    private let sendLock = NSLock()
    private let reconnectInterval: TimeInterval = 3.0
    private let maxReconnectInterval: TimeInterval = 30.0
    private var currentReconnectInterval: TimeInterval = 3.0
    private var shouldReconnect = true
    private var currentLanguage: String = SettingsManager.shared.voiceLanguage
    private var lastErrorMessage: String?

    // 引用 SettingsManager 获取配置
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager = .shared) {
        self.settingsManager = settingsManager

        // Observe voice settings changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged(_:)),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    func connect() {
        // 先取消正在进行的重连任务，防止并发竞争
        reconnectTask?.cancel()
        reconnectTask = nil

        // 清理旧连接
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        shouldReconnect = true
        currentReconnectInterval = reconnectInterval

        let task = session.webSocketTask(with: serverURL)
        webSocketTask = task
        task.resume()

        // 延迟发送 ping，等待 WebSocket 握手完成
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.webSocketTask === task else { return }

            task.sendPing { [weak self] error in
                guard let self = self, self.webSocketTask === task else { return }

                if let error {
                    print("[ASRClient] Ping failed after connect: \(error)")
                    self.handleDisconnect(error: error)
                    return
                }

                self.isConnected = true
                DispatchQueue.main.async { [weak self] in
                    self?.onConnectionStatusChanged?(true)
                    self?.lastErrorMessage = nil
                    self?.onErrorStateChanged?(false, nil)
                }
                print("[ASRClient] Connected to \(self.serverURL)")
            }
        }

        listenForMessages()
    }

    func disconnect() {
        shouldReconnect = false
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        if isConnected {
            isConnected = false
            DispatchQueue.main.async { [weak self] in
                self?.onConnectionStatusChanged?(false)
            }
        }
        reconnectTask?.cancel()
        reconnectTask = nil
    }

    /// 带回调的 sendStart，确保 start 消息发送完成后再回调
    /// - Parameter mode: 录音模式，"voice_input"(默认语音输入) 或 "subtitle"(系统音频字幕)
    func sendStart(mode: String = "voice_input", completion: @escaping () -> Void) {
        let profile = SceneManager.shared.getEffectiveProfile()
        let modelId = settingsManager.modelSize.modelId

        // 获取当前活跃应用信息（用于上下文语调适配）
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let activeAppInfo: [String: String] = [
            "name": frontmostApp?.localizedName ?? "",
            "bundle_id": frontmostApp?.bundleIdentifier ?? ""
        ]

        // 判断是否启用 LLM 纠错（全局是总开关，场景可在全局开启时禁用）
        let shouldUseLLM = settingsManager.llmSettings.isEnabled && (profile.useLLMPolish ?? true)

        // 构建基础消息
        var message: [String: Any] = [
            "type": "start",
            "mode": mode,
            "enable_polish": profile.enablePolish ? "true" : "false",
            "use_llm_polish": shouldUseLLM,
            "use_timestamps": settingsManager.useTimestamps,
            "enable_denoise": settingsManager.enableDenoise,
            "model_id": modelId,
            "language": profile.getEffectiveLanguage().rawValue,
            "active_app": activeAppInfo
        ]

        // 添加场景信息
        var sceneInfo: [String: Any] = [
            "type": profile.sceneType.rawValue,
            "polish_style": profile.polishStyle.rawValue
        ]
        if let customPrompt = profile.customPrompt, !customPrompt.isEmpty {
            sceneInfo["custom_prompt"] = customPrompt
        } else if let defaultPrompt = profile.getEffectivePrompt() {
            sceneInfo["custom_prompt"] = defaultPrompt
        }

        message["scene"] = sceneInfo

        sendJSONObject(message, completion: completion)
    }

    /// 向后兼容的无参版本
    func sendStart(mode: String = "voice_input") {
        sendStart(mode: mode, completion: {})
    }

    private func sendJSONObject(_ dict: [String: Any], completion: (() -> Void)? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            completion?()
            return
        }
        let message = URLSessionWebSocketTask.Message.string(str)
        webSocketTask?.send(message) { error in
            if let error {
                print("[ASRClient] Send JSON error: \(error)")
            }
            completion?()
        }
    }

    /// 带回调的 sendStop，确保 stop 消息发送完成后再回调
    func sendStop(completion: @escaping () -> Void) {
        sendJSON(["type": "stop"], completion: completion)
    }

    /// 向后兼容的无参版本
    func sendStop() {
        sendStop(completion: {})
    }

    /// 发送音频块，追踪 pending 数量
    func sendAudioChunk(_ data: Data) {
        sendLock.lock()
        pendingAudioSends += 1
        sendLock.unlock()

        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error {
                print("[ASRClient] Send audio error: \(error)")
            }
            self?.sendLock.lock()
            self?.pendingAudioSends -= 1
            self?.sendLock.unlock()
        }
    }

    /// 等待所有音频块发送完成
    func flushAudioChunks(completion: @escaping () -> Void) {
        DispatchQueue.global().async { [weak self] in
            var waited = 0
            while waited < 500 {  // 最多等待500ms
                self?.sendLock.lock()
                let pending = self?.pendingAudioSends ?? 0
                self?.sendLock.unlock()
                if pending == 0 { break }
                Thread.sleep(forTimeInterval: 0.01)
                waited += 10
            }
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - Private

    private func sendJSON(_ dict: [String: String], completion: (() -> Void)? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else {
            completion?()
            return
        }
        let message = URLSessionWebSocketTask.Message.string(str)
        webSocketTask?.send(message) { error in
            if let error {
                print("[ASRClient] Send JSON error: \(error)")
            }
            completion?()
        }
    }

    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                self.handleMessage(message)
                self.listenForMessages()
            case .failure(let error):
                print("[ASRClient] Receive error: \(error)")
                self.handleDisconnect(error: error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        // Try to decode as generic JSON first to handle different message types
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let typeString = json["type"] as? String else {
            return
        }

        switch typeString {
        case "final":
            let text = json["text"] as? String ?? ""
            let originalText = json["original_text"] as? String
            let polishMethod = json["polish_method"] as? String
            NSLog("[ASRClient] Received final: text=\(text), polish_method=\(polishMethod ?? "nil")")
            DispatchQueue.main.async { [weak self] in
                self?.onTranscriptionResult?(text)
                if let original = originalText { self?.onOriginalTextReceived?(original) }
                if let method = polishMethod { self?.onPolishMethodReceived?(method) }
            }

        case "partial":
            let text = json["text"] as? String ?? ""
            let trigger = json["trigger"] as? String ?? "periodic"
            DispatchQueue.main.async { [weak self] in
                self?.onPartialResult?(text, trigger)
            }

        case "polish_update":
            let text = json["text"] as? String ?? ""
            NSLog("[ASRClient] Received polish_update: text=%@", text)
            DispatchQueue.main.async { [weak self] in
                self?.onPolishUpdate?(text)
            }

        case "config_llm_ack":
            let success = json["success"] as? Bool ?? false
            NSLog("[ASRClient] LLM config ack: success=\(success)")

        case "test_llm_connection_result":
            let success = json["success"] as? Bool ?? false
            let latency = json["latency_ms"] as? Int
            NSLog("[ASRClient] LLM connection test: success=\(success), latency=\(latency ?? -1)ms")
            DispatchQueue.main.async { [weak self] in
                self?.onLLMConnectionTestResult?(success, latency)
            }

        case "analysis_result":
            if let resultDict = json["result"] as? [String: Any],
               let result = HistoryAnalysisResult.fromServerResponse(resultDict) {
                NSLog("[ASRClient] History analysis complete: \(result.analyzedCount) entries, \(result.keywords.count) keywords")
                DispatchQueue.main.async { [weak self] in
                    self?.onHistoryAnalysisResult?(result)
                }
            } else {
                NSLog("[ASRClient] History analysis failed or empty result")
                DispatchQueue.main.async { [weak self] in
                    self?.onHistoryAnalysisResult?(nil)
                }
            }

        case "default_prompts":
            if let prompts = json["prompts"] as? [String: String] {
                NSLog("[ASRClient] Received default prompts: \(prompts.count) scenes")
                DispatchQueue.main.async { [weak self] in
                    self?.onDefaultPromptsReceived?(prompts)
                }
            }

        case "custom_prompts":
            if let prompts = json["prompts"] as? [String: String] {
                NSLog("[ASRClient] Received custom prompts: \(prompts.count) scenes")
                DispatchQueue.main.async { [weak self] in
                    self?.onCustomPromptsReceived?(prompts)
                }
            }

        case "save_custom_prompt_ack":
            let success = json["success"] as? Bool ?? false
            let sceneType = json["scene_type"] as? String ?? ""
            NSLog("[ASRClient] Save prompt ack: scene=%@, success=%@", sceneType, success ? "true" : "false")
            DispatchQueue.main.async { [weak self] in
                self?.onPromptSaved?(sceneType, success)
            }

        default:
            NSLog("[ASRClient] Unknown message type: \(typeString)")
        }
    }

    private func isRecoverable(_ error: Error?) -> Bool {
        guard let error = error else { return true }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet, .resourceUnavailable:
                return true
            case .badURL, .unsupportedURL:
                return false
            default:
                return true
            }
        }
        return true
    }

    private func handleDisconnect(error: Error?) {
        let message = (error as NSError?)?.localizedDescription ?? "Connection lost"

        // 只在已连接状态下触发断开回调，避免重复通知
        if isConnected {
            isConnected = false
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.onConnectionStatusChanged?(false)
                self.lastErrorMessage = message
                self.onErrorStateChanged?(true, self.lastErrorMessage)
            }
        }

        // Respect manual disconnect
        guard shouldReconnect else { return }

        // Stop reconnecting for unrecoverable errors
        if !isRecoverable(error) {
            shouldReconnect = false
            return
        }

        // 如果已有重连任务在运行，不再创建新的
        guard reconnectTask == nil else { return }

        // Start reconnect task with exponential backoff
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            var delay = self.currentReconnectInterval

            while !Task.isCancelled && self.shouldReconnect && !self.isConnected {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled && self.shouldReconnect else { break }

                print("[ASRClient] Attempting reconnect after \(delay)s...")
                self.connect()

                // 等待连接结果
                try? await Task.sleep(nanoseconds: 1_000_000_000)

                if self.isConnected { break }

                // Exponential backoff up to a maximum
                delay = min(self.maxReconnectInterval, delay * 2)
                self.currentReconnectInterval = delay
            }

            // 任务结束时清理自身引用
            self.reconnectTask = nil
        }
    }

    // MARK: - Settings Observer

    @objc private func handleSettingsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String,
              let key = userInfo["key"] as? String else {
            return
        }

        // Update language when voice language setting changes
        if category == "voice" && key == "language" {
            if let language = userInfo["value"] as? String {
                currentLanguage = language
                NSLog("[ASRClient] Voice language changed to: \(language)")
            }
        }

        // Sync LLM settings when changed
        if category == "llm" && key == "settings" {
            configureLLM(settingsManager.llmSettings)
        }
    }

    // MARK: - LLM Methods

    /// Configure LLM settings on server
    func configureLLM(_ settings: LLMSettings) {
        let configDict: [String: Any] = [
            "type": "config_llm",
            "config": settings.toDictionary()
        ]
        sendJSONObject(configDict)
        NSLog("[ASRClient] Sent LLM config: model=\(settings.model)")
    }

    /// Test LLM connection
    func testLLMConnection() {
        let message: [String: Any] = ["type": "test_llm_connection"]
        sendJSONObject(message)
        NSLog("[ASRClient] Testing LLM connection...")
    }

    /// Analyze recording history for an application
    func analyzeHistory(entries: [RecordingEntry], appName: String, existingTerms: [String] = []) {
        let entriesData = entries.map { entry -> [String: Any] in
            return [
                "text": entry.text,
                "timestamp": entry.timestamp.timeIntervalSince1970,
                "app_name": entry.appName ?? "",
                "bundle_id": entry.bundleID ?? ""
            ]
        }

        let message: [String: Any] = [
            "type": "analyze_history",
            "entries": entriesData,
            "app_name": appName,
            "existing_terms": existingTerms
        ]
        sendJSONObject(message)
        NSLog("[ASRClient] Sent history analysis request: \(entries.count) entries for \(appName)")
    }

    // MARK: - Prompt Management Methods

    /// Request default prompts from server
    func requestDefaultPrompts() {
        let message: [String: Any] = ["type": "get_default_prompts"]
        sendJSONObject(message)
        NSLog("[ASRClient] Requesting default prompts...")
    }

    /// Request custom prompts from server
    func requestCustomPrompts() {
        let message: [String: Any] = ["type": "get_custom_prompts"]
        sendJSONObject(message)
        NSLog("[ASRClient] Requesting custom prompts...")
    }

    /// Save custom prompt for a scene type
    func saveCustomPrompt(sceneType: String, prompt: String?, useDefault: Bool) {
        var message: [String: Any] = [
            "type": "save_custom_prompt",
            "scene_type": sceneType,
            "use_default": useDefault
        ]
        if let prompt = prompt {
            message["prompt"] = prompt
        }
        sendJSONObject(message)
        NSLog("[ASRClient] Saving custom prompt for scene: %@, useDefault: %@", sceneType, useDefault ? "true" : "false")
    }

    /// Send start with LLM polish option
    func sendStartWithLLM(useLLMPolish: Bool) {
        let profile = SceneManager.shared.getEffectiveProfile()
        let modelId = settingsManager.modelSize.modelId

        // 获取当前活跃应用信息
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let activeAppInfo: [String: String] = [
            "name": frontmostApp?.localizedName ?? "",
            "bundle_id": frontmostApp?.bundleIdentifier ?? ""
        ]

        // 判断是否启用 LLM 纠错（全局是总开关，场景可在全局开启时禁用）
        let shouldUseLLM = settingsManager.llmSettings.isEnabled && (profile.useLLMPolish ?? true)

        var message: [String: Any] = [
            "type": "start",
            "enable_polish": profile.enablePolish ? "true" : "false",
            "use_llm_polish": shouldUseLLM,
            "enable_denoise": settingsManager.enableDenoise,
            "model_id": modelId,
            "language": profile.getEffectiveLanguage().rawValue,
            "active_app": activeAppInfo
        ]

        var sceneInfo: [String: Any] = [
            "type": profile.sceneType.rawValue,
            "polish_style": profile.polishStyle.rawValue
        ]
        if let customPrompt = profile.customPrompt, !customPrompt.isEmpty {
            sceneInfo["custom_prompt"] = customPrompt
        } else if let defaultPrompt = profile.getEffectivePrompt() {
            sceneInfo["custom_prompt"] = defaultPrompt
        }

        message["scene"] = sceneInfo
        sendJSONObject(message)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        reconnectTask?.cancel()
        disconnect()
    }
}

