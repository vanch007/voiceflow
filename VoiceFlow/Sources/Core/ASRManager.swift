import Foundation
import Combine
import AppKit

/// ASR 后端管理器
/// 管理 Native 和 WebSocket 两种后端，支持运行时切换
final class ASRManager: ObservableObject {
    private let settingsManager: SettingsManager

    /// Native ASR 引擎
    let nativeEngine: NativeASREngine

    /// WebSocket ASR 客户端
    let websocketClient: ASRClient

    /// 当前活跃的后端
    var activeBackend: ASRBackend {
        switch settingsManager.asrBackendType {
        case .native:
            return nativeEngine
        case .websocket:
            return websocketClient
        }
    }

    /// 当前后端类型
    var backendType: ASRBackendType {
        settingsManager.asrBackendType
    }

    // MARK: - 模型状态（仅 Native 模式）

    @Published var isModelLoading = false
    @Published var modelLoadProgress = ""
    @Published var isModelLoaded = false
    @Published var isModelDownloaded = false

    /// 检查当前选中的模型是否已下载
    func checkModelDownloaded() -> Bool {
        let modelId = settingsManager.nativeModelId
        isModelDownloaded = nativeEngine.isModelDownloaded(modelId)
        return isModelDownloaded
    }

    /// 下载 Native 模型
    func downloadNativeModel() async {
        isModelLoading = true
        modelLoadProgress = "正在下载模型..."
        let success = await nativeEngine.downloadModel()
        isModelLoading = false
        isModelDownloaded = success
        isModelLoaded = success
        modelLoadProgress = ""
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - 回调转发

    /// 统一回调接口 - 外部绑定到这些回调，ASRManager 自动转发到活跃后端
    var onTranscriptionResult: ((String) -> Void)? {
        didSet { syncCallbacks() }
    }
    var onPartialResult: ((String, String) -> Void)? {
        didSet { syncCallbacks() }
    }
    var onPolishUpdate: ((String) -> Void)? {
        didSet { syncCallbacks() }
    }
    var onConnectionStatusChanged: ((Bool) -> Void)? {
        didSet { syncCallbacks() }
    }
    var onErrorStateChanged: ((Bool, String?) -> Void)? {
        didSet { syncCallbacks() }
    }
    var onOriginalTextReceived: ((String) -> Void)? {
        didSet { syncCallbacks() }
    }
    var onPolishMethodReceived: ((String) -> Void)? {
        didSet { syncCallbacks() }
    }

    init(settingsManager: SettingsManager = .shared) {
        self.settingsManager = settingsManager
        self.nativeEngine = NativeASREngine()
        self.websocketClient = ASRClient(settingsManager: settingsManager)

        // 监听后端类型变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged(_:)),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public API

    /// 连接当前后端
    func connect() {
        syncCallbacks()
        activeBackend.connect()
    }

    /// 断开当前后端
    func disconnect() {
        nativeEngine.disconnect()
        websocketClient.disconnect()
    }

    /// 加载 Native 模型（仅 Native 模式需要）
    /// - Parameter forceReload: 强制重新加载模型
    func loadNativeModel(forceReload: Bool = true) async {
        isModelLoading = true
        modelLoadProgress = "正在加载模型..."
        await nativeEngine.loadModel(forceReload: forceReload)
        isModelLoading = false
        isModelLoaded = nativeEngine.isModelLoaded
        modelLoadProgress = ""
    }

    /// 切换后端类型
    func switchBackend(to type: ASRBackendType) {
        let oldType = settingsManager.asrBackendType
        guard oldType != type else { return }

        NSLog("[ASRManager] Switching backend: %@ -> %@", oldType.rawValue, type.rawValue)

        // 断开旧后端
        activeBackend.disconnect()

        // 更新设置
        settingsManager.asrBackendType = type

        // 同步回调到新后端
        syncCallbacks()

        // 连接新后端
        activeBackend.connect()
    }

    /// 构建 ASR 会话配置（从当前设置构建）
    func buildSessionConfig(mode: ASRMode = .voiceInput) -> ASRSessionConfig {
        let profile = SceneManager.shared.getEffectiveProfile()
        let vocabularyStorage = VocabularyStorage()
        let hotwords = vocabularyStorage.getTerms(from: profile.vocabularyRuleIDs)
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        let shouldUseLLM = settingsManager.llmSettings.isEnabled && (profile.useLLMPolish ?? true)

        var sceneInfo: SceneSessionInfo?
        let customPrompt = profile.customPrompt ?? profile.getEffectivePrompt()
        sceneInfo = SceneSessionInfo(
            type: profile.sceneType.rawValue,
            polishStyle: profile.polishStyle.rawValue,
            customPrompt: customPrompt
        )

        return ASRSessionConfig(
            mode: mode,
            language: profile.getEffectiveLanguage(),
            enablePolish: profile.enablePolish,
            useLLMPolish: shouldUseLLM,
            modelId: settingsManager.modelSize.modelId,
            hotwords: hotwords,
            scene: sceneInfo,
            useTimestamps: settingsManager.useTimestamps,
            enableDenoise: settingsManager.enableDenoise,
            activeApp: [
                "name": frontmostApp?.localizedName ?? "",
                "bundle_id": frontmostApp?.bundleIdentifier ?? ""
            ]
        )
    }

    // MARK: - Private

    /// 将回调同步到当前活跃后端
    private func syncCallbacks() {
        let backend = activeBackend
        backend.onTranscriptionResult = onTranscriptionResult
        backend.onPartialResult = onPartialResult
        backend.onPolishUpdate = onPolishUpdate
        backend.onConnectionStatusChanged = onConnectionStatusChanged
        backend.onErrorStateChanged = onErrorStateChanged
        backend.onOriginalTextReceived = onOriginalTextReceived
        backend.onPolishMethodReceived = onPolishMethodReceived
    }

    @objc private func handleSettingsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String else { return }

        if category == "asr" {
            // 后端类型或模型变更时重新同步
            syncCallbacks()
        }
    }
}
