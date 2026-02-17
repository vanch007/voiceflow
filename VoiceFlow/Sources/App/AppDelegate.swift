import AppKit
import AudioToolbox
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Cache paths on first access to avoid recalculation issues during runtime
    private static var _cachedPythonPath: String?
    private static var _cachedServerScriptPath: String?

    /// Resolve paths relative to the app bundle's parent directory (project root).
    /// e.g. /path/to/voiceflow/VoiceFlow.app → /path/to/voiceflow
    private static var projectRoot: String {
        let bundlePath = Bundle.main.bundlePath
        return (bundlePath as NSString).deletingLastPathComponent
    }

    private static var pythonPath: String {
        // Return cached path if available
        if let cached = _cachedPythonPath {
            return cached
        }

        // Priority 1: Environment variable (set by run.sh or Xcode scheme)
        if let envPath = ProcessInfo.processInfo.environment["VOICEFLOW_PYTHON"] {
            _cachedPythonPath = envPath
            return envPath
        }

        // Priority 2: Check common locations relative to home directory
        let homeDir = NSHomeDirectory()
        let commonPythonPaths = [
            "\(homeDir)/voiceflow/.venv/bin/python3",
            "\(homeDir)/VoiceFlow/.venv/bin/python3",
            "\(homeDir)/Projects/voiceflow/.venv/bin/python3"
        ]
        for path in commonPythonPaths {
            if FileManager.default.fileExists(atPath: path) {
                _cachedPythonPath = path
                return path
            }
        }

        // Priority 3: Search upwards from bundle path for .venv directory
        var searchPath = projectRoot
        for _ in 0..<6 {
            let venvPath = (searchPath as NSString).appendingPathComponent(".venv/bin/python3")
            if FileManager.default.fileExists(atPath: venvPath) {
                _cachedPythonPath = venvPath
                return venvPath
            }
            searchPath = (searchPath as NSString).deletingLastPathComponent
        }

        // Priority 4: Fallback to projectRoot calculation
        let fallbackPath = (projectRoot as NSString).appendingPathComponent(".venv/bin/python3")
        _cachedPythonPath = fallbackPath
        return fallbackPath
    }

    private static var serverScriptPath: String {
        // Return cached path if available
        if let cached = _cachedServerScriptPath {
            return cached
        }

        // Priority 1: Environment variable VOICEFLOW_PROJECT_ROOT
        if let envRoot = ProcessInfo.processInfo.environment["VOICEFLOW_PROJECT_ROOT"] {
            let scriptPath = (envRoot as NSString).appendingPathComponent("server/main.py")
            if FileManager.default.fileExists(atPath: scriptPath) {
                _cachedServerScriptPath = scriptPath
                return scriptPath
            }
        }

        // Priority 2: Check common locations relative to home directory
        let homeDir = NSHomeDirectory()
        let commonPaths = [
            "\(homeDir)/voiceflow/server/main.py",
            "\(homeDir)/VoiceFlow/server/main.py",
            "\(homeDir)/Projects/voiceflow/server/main.py"
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                _cachedServerScriptPath = path
                return path
            }
        }

        // Priority 3: Search upwards from bundle path for server/main.py
        var searchPath = projectRoot
        for _ in 0..<6 {
            let scriptPath = (searchPath as NSString).appendingPathComponent("server/main.py")
            if FileManager.default.fileExists(atPath: scriptPath) {
                _cachedServerScriptPath = scriptPath
                return scriptPath
            }
            searchPath = (searchPath as NSString).deletingLastPathComponent
        }

        // Fallback to projectRoot calculation
        let fallbackPath = (projectRoot as NSString).appendingPathComponent("server/main.py")
        _cachedServerScriptPath = fallbackPath
        return fallbackPath
    }

    private var statusBarController: StatusBarController!
    private var settingsWindowController: SettingsWindowController!
    private var hotkeyManager: HotkeyManager!
    private var hotkeySettingsWindow: HotkeySettingsWindow!
    private var recordingHistoryWindow: RecordingHistoryWindow!
    private var audioRecorder: AudioRecorder!
    private var asrManager: ASRManager!
    private var textInjector: TextInjector!
    private var overlayPanel: OverlayPanel!
    private var settingsManager: SettingsManager!
    private var recordingHistory: RecordingHistory!
    private var replacementStorage: ReplacementStorage!
    private var replacementEngine: TextReplacementEngine!
    private var pluginManager: PluginManager!
    private var permissionAlertWindow: PermissionAlertWindow!
    private var onboardingWindow: OnboardingWindow?
    private var sceneManager: SceneManager!
    private var termLearner: TermLearner!
    private var isRecording = false
    private var asrServerProcess: Process?
    private var recordingStartTime: Date?

    // System audio recording
    private var systemAudioRecorder: SystemAudioRecorder?
    private var subtitlePanel: SubtitlePanel!
    private var isSystemAudioRecording = false
    private var systemAudioStartTime: Date?

    private var startSoundID: SystemSoundID = 0
    private var stopSoundID: SystemSoundID = 0
    private var cancellables = Set<AnyCancellable>()

    /// PID file path for tracking ASR server process
    private static var pidFilePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let voiceflowDir = appSupport.appendingPathComponent("VoiceFlow")
        try? FileManager.default.createDirectory(at: voiceflowDir, withIntermediateDirectories: true)
        return voiceflowDir.appendingPathComponent("asr_server.pid").path
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[AppDelegate] applicationDidFinishLaunching called!")
        NSLog("[AppDelegate] Model cache directory: ~/Library/Caches/qwen3-speech")

        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Setup signal handlers to terminate Python subprocess on Ctrl+C
        setupSignalHandlers()

        // Check permissions before initializing managers
        let permissionStatus = PermissionManager.shared.checkAllPermissions()
        NSLog("[AppDelegate] Permission check - Accessibility: %@, Microphone: %@",
              permissionStatus.isAccessibilityGranted ? "granted" : "not granted",
              permissionStatus.isMicrophoneGranted ? "granted" : "not granted")

        // Show permission alert if any permission is missing
        permissionAlertWindow = PermissionAlertWindow()
        permissionAlertWindow.onRetryCheck = { [weak self] in
            guard let self else { return }
            let status = PermissionManager.shared.checkAllPermissions()
            if status.isAccessibilityGranted {
                self.hotkeyManager?.start()
                NSLog("[AppDelegate] HotkeyManager restarted after permission granted")
            }
        }
        if !permissionStatus.isAccessibilityGranted || !permissionStatus.isMicrophoneGranted {
            NSLog("[AppDelegate] Missing permissions detected, showing alert window")
            permissionAlertWindow.show()
        }

        // Load sounds via AudioServices (bypasses AVCaptureSession output blocking)
        loadSounds()

        setupManagers()

        // 根据后端类型条件化启动 Python 服务器
        // WebSocket 模式需要启动服务器，Native 模式直接使用本地模型
        if asrManager.backendType == .websocket {
            startASRServer()
        } else {
            NSLog("[AppDelegate] Using Native ASR backend, skipping Python server startup")
        }

        setupAudioPipeline()
        setupUIComponents()
        setupEventHandlers()
    }

    // MARK: - Initialization Phases

    /// Initialize settings, replacement engine, plugins, and scene manager
    private func setupManagers() {
        settingsManager = SettingsManager.shared
        replacementStorage = ReplacementStorage()

        // Migrate existing glossaries and import default presets
        replacementStorage.migrateExistingGlossaries(from: SceneManager.shared)
        replacementStorage.importDefaultGlossariesIfNeeded()

        replacementEngine = TextReplacementEngine(storage: replacementStorage)
        recordingHistory = RecordingHistory()

        // Initialize ASRManager for both Native and WebSocket backends
        asrManager = ASRManager(settingsManager: settingsManager)

        settingsWindowController = SettingsWindowController(
            settingsManager: settingsManager,
            replacementStorage: replacementStorage,
            recordingHistory: recordingHistory,
            asrManager: asrManager
        )

        // Initialize plugin system
        pluginManager = PluginManager.shared
        pluginManager.discoverPlugins()

        // Initialize scene manager for automatic scene detection
        sceneManager = SceneManager.shared
        NSLog("[AppDelegate] SceneManager initialized, current scene: %@", sceneManager.currentScene.rawValue)

        // Observe settings changes for real-time application
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged(_:)),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    /// Configure audio recorder, ASR client, and their callbacks
    private func setupAudioPipeline() {
        overlayPanel = OverlayPanel()
        textInjector = TextInjector()

        // ASRManager already initialized in setupManagers for SettingsWindowController
        // PromptManager 仅用于 WebSocket 模式（需要从 Python 服务器获取提示词）
        if asrManager.backendType == .websocket {
            PromptManager.shared.configure(with: asrManager.websocketClient)
        }
        termLearner = TermLearner()
        // Connect RecordingHistory changes to TermLearner auto-refresh
        NotificationCenter.default.addObserver(forName: RecordingHistory.entriesDidChangeNotification, object: recordingHistory, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            self.termLearner.analyzeAndRefresh(from: self.recordingHistory)
        }
        audioRecorder = AudioRecorder()
        audioRecorder.onAudioChunk = { [weak self] data in
            self?.asrManager.activeBackend.feedAudioChunk(data)
        }
        audioRecorder.onVolumeLevel = { [weak self] volume in
            DispatchQueue.main.async {
                self?.overlayPanel.updateVolume(Double(volume))
                // 更新静音倒计时显示
                if let silenceDuration = self?.audioRecorder.getCurrentSilenceDuration() {
                    self?.overlayPanel.updateSilenceCountdown(silenceDuration, threshold: 2.0)
                }
            }
        }

        // 静音检测回调（自由说话模式）
        audioRecorder.onSilenceDetected = { [weak self] in
            guard let self = self, self.isRecording else { return }
            NSLog("[AppDelegate] Silence detected, auto-stopping recording")
            self.stopRecording()
        }

        // SNR 更新回调（噪声环境自适应）
        audioRecorder.onSNRUpdated = { [weak self] snr, _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.overlayPanel.updateSNR(snr)
            }
        }

        asrManager.onTranscriptionResult = { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async {
                // Apply text replacement rules
                var processedText = self.replacementEngine.applyReplacements(to: text)

                // Process text through plugins
                processedText = self.pluginManager.processText(processedText)

                NSLog("[AppDelegate] onTranscriptionResult: isSystemAudioRecording=%@, text=%@",
                      self.isSystemAudioRecording ? "true" : "false", processedText)

                // 系统音频录制时：添加到字幕面板，不注入文本
                if self.isSystemAudioRecording {
                    if !processedText.isEmpty {
                        self.subtitlePanel.addFinalSubtitle(processedText)
                    }
                    // 收到 final 结果后，重置系统音频录制状态
                    self.isSystemAudioRecording = false
                    self.subtitlePanel.stopRecording()
                    self.statusBarController.updateStatus(.idle)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.subtitlePanel.hide()
                    }
                    return
                }

                // 麦克风录音模式：必须有 recordingStartTime 才显示完成（防止残留响应）
                guard self.recordingStartTime != nil else {
                    NSLog("[AppDelegate] Ignoring stale transcription result (no active recording)")
                    return
                }

                self.overlayPanel.showDone()
                self.statusBarController.updateStatus(.idle)
                if !processedText.isEmpty {
                    self.textInjector.inject(text: processedText)
                }

                // Add to recording history with processed text
                if let startTime = self.recordingStartTime {
                    let duration = Date().timeIntervalSince(startTime)
                    // Get current frontmost app info
                    let frontmostApp = NSWorkspace.shared.frontmostApplication
                    let appName = frontmostApp?.localizedName
                    let bundleID = frontmostApp?.bundleIdentifier
                    self.recordingHistory.addEntry(text: processedText, duration: duration, appName: appName, bundleID: bundleID)
                    self.recordingStartTime = nil
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.overlayPanel.hide()
                }
            }
        }

        asrManager.onPartialResult = { [weak self] text, trigger in
            guard let self else { return }
            DispatchQueue.main.async {
                // 系统音频录制时：只更新字幕面板，不更新 overlayPanel
                if self.isSystemAudioRecording {
                    self.subtitlePanel.updatePartialSubtitle(text, trigger: trigger)
                    return
                }

                // 麦克风录音时：更新 overlayPanel
                self.overlayPanel.updateRecordingText(text)
            }
        }

        asrManager.onOriginalTextReceived = { originalText in
            NSLog("[AppDelegate] Original text received: %@", originalText)
        }

        asrManager.onPolishUpdate = { [weak self] updatedText in
            guard let self else { return }
            DispatchQueue.main.async {
                NSLog("[AppDelegate] Received polish update: %@", updatedText)

                // 应用文本替换规则
                var processedText = self.replacementEngine.applyReplacements(to: updatedText)
                processedText = self.pluginManager.processText(processedText)

                // 使用全选+粘贴替换已输入的文本
                self.textInjector.replaceLastInjectedText(with: processedText)
            }
        }

        asrManager.onConnectionStatusChanged = { [weak self] connected in
            DispatchQueue.main.async {
                self?.statusBarController.updateConnectionStatus(connected: connected)
                // 连接成功后自动同步 LLM 配置到服务器
                if connected, let self = self {
                    let llmSettings = self.settingsManager.llmSettings
                    if llmSettings.isEnabled && self.asrManager.backendType == .websocket {
                        // 仅 WebSocket 模式需要配置远程 LLM
                        self.asrManager.activeBackend.connect()
                    }
                    NSLog("[AppDelegate] Auto-synced LLM config on connect: model=%@", llmSettings.model)
                }
            }
        }

        asrManager.onErrorStateChanged = { [weak self] hasError, errorMessage in
            DispatchQueue.main.async {
                self?.statusBarController.updateErrorState(hasError: hasError, message: errorMessage)
            }
        }
    }

    /// Create status bar, hotkey manager, subtitle panel, and wire up menu actions
    private func setupUIComponents() {
        statusBarController = StatusBarController()
        statusBarController.onQuit = {
            NSApp.terminate(nil)
        }
        statusBarController.onSettings = { [weak self] in
            self?.settingsWindowController.show()
        }
        statusBarController.onShowOnboarding = { [weak self] in
            self?.showOnboarding()
        }
        statusBarController.onShowHistory = { [weak self] in
            self?.recordingHistoryWindow.show()
        }
        statusBarController.onTextReplacement = { [weak self] in
            self?.settingsWindowController.show(tab: .textReplacement)
        }
        statusBarController.onDeviceSelected = { [weak self] deviceID in
            self?.audioRecorder.selectDevice(id: deviceID)
        }
        audioRecorder.onDeviceChanged = { [weak self] name in
            self?.statusBarController.updateActiveDevice(name: name)
        }

        hotkeyManager = HotkeyManager()
        hotkeyManager.onLongPress = { [weak self] in
            self?.startRecording()
        }
        hotkeyManager.onLongPressEnd = { [weak self] in
            self?.stopRecording()
        }
        hotkeyManager.onToggleRecording = { [weak self] in
            guard let self = self else { return }
            if self.isRecording {
                self.stopRecording()
            } else {
                self.startRecordingFreeSpeak()
            }
        }

        // 双击 Option：系统音频录制切换
        hotkeyManager.onSystemAudioDoubleTap = { [weak self] in
            self?.toggleSystemAudioRecording()
        }

        hotkeyManager.start()

        // Initialize hotkey settings window
        hotkeySettingsWindow = HotkeySettingsWindow()
        hotkeySettingsWindow.onSave = { [weak self] voiceConfig, systemAudioConfig in
            self?.hotkeyManager.saveConfig(voiceConfig)
            self?.hotkeyManager.saveSystemAudioConfig(systemAudioConfig)
        }

        // Setup hotkey settings action (separate from main settings)
        statusBarController.onHotkeySettings = { [weak self] in
            self?.hotkeySettingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }

        // Initialize recording history window
        recordingHistoryWindow = RecordingHistoryWindow(recordingHistory: recordingHistory)

        // 状态栏菜单触发系统音频录制
        statusBarController.onToggleSystemAudio = { [weak self] in
            self?.toggleSystemAudioRecording()
        }

        // Initialize subtitle panel for system audio transcription
        subtitlePanel = SubtitlePanel()
    }

    /// Bind notification observers, restore device selection, connect ASR, and show onboarding
    private func setupEventHandlers() {
        // Observe hotkey enabled setting
        settingsManager.$hotkeyEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.hotkeyManager.enable()
                } else {
                    self?.hotkeyManager.disable()
                }
            }
            .store(in: &cancellables)

        // Restore saved device selection
        if let savedDeviceID = UserDefaults.standard.string(forKey: "selectedAudioDevice") {
            audioRecorder.selectDevice(id: savedDeviceID)
        } else {
            audioRecorder.prepare()
        }

        // Wait briefly for ASR server to start (if using WebSocket), then connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }

            // 根据后端类型处理
            if self.asrManager.backendType == .websocket {
                // WebSocket 模式：已在 startASRServer() 中启动了 Python 服务器
                self.asrManager.connect()
            } else {
                // Native 模式：启动时加载模型
                Task {
                    await self.asrManager.loadNativeModel()
                }
            }
        }

        // Show onboarding wizard on first launch
        if !settingsManager.hasCompletedOnboarding {
            showOnboarding()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pluginManager.unloadAll()
        NotificationCenter.default.removeObserver(self)

        // 根据后端类型清理资源
        asrManager.disconnect()

        // 仅 WebSocket 模式需要停止 Python 服务器
        if asrManager.backendType == .websocket {
            stopASRServer()
        }
    }

    // MARK: - Settings Observer

    @objc private func handleSettingsChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String,
              let key = userInfo["key"] as? String else {
            return
        }

        if category == "general" && key == "soundEffectsEnabled" {
            if let enabled = userInfo["value"] as? Bool {
                NSLog("[Settings] Sound effects %@", enabled ? "enabled" : "disabled")
            }
        }

        // Sync LLM settings - handled by LLMPolisher for both Native and WebSocket modes
        if category == "llm" && key == "settings" {
            NSLog("[Settings] LLM config updated: model=%@", settingsManager.llmSettings.model)
            // LLM 润色现在由 LLMPolisher 直接处理，无需同步到服务器
        }
    }

    // MARK: - ASR Server Management

    /// Kill any orphan ASR server process from previous sessions
    private func cleanupOrphanASRServer() {
        let pidFile = Self.pidFilePath
        guard FileManager.default.fileExists(atPath: pidFile),
              let pidString = try? String(contentsOfFile: pidFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
              let pid = Int32(pidString) else {
            return
        }

        // Check if process is still running
        if kill(pid, 0) == 0 {
            NSLog("[ASRServer] Found orphan process (PID: %d), terminating...", pid)
            kill(pid, SIGTERM)
            // Give it a moment to terminate gracefully
            usleep(500_000) // 500ms
            // Force kill if still running
            if kill(pid, 0) == 0 {
                kill(pid, SIGKILL)
                NSLog("[ASRServer] Force killed orphan process (PID: %d)", pid)
            }
        }

        // Clean up PID file
        try? FileManager.default.removeItem(atPath: pidFile)
    }

    /// Write current ASR server PID to file for cleanup on next launch
    private func writeASRServerPID(_ pid: Int32) {
        do {
            try String(pid).write(toFile: Self.pidFilePath, atomically: true, encoding: .utf8)
            NSLog("[ASRServer] PID file written: %@", Self.pidFilePath)
        } catch {
            NSLog("[ASRServer] Failed to write PID file: %@", error.localizedDescription)
        }
    }

    /// Remove PID file after server stops
    private func removeASRServerPIDFile() {
        try? FileManager.default.removeItem(atPath: Self.pidFilePath)
    }

    private func startASRServer() {
        // Clean up any orphan server from previous crash/force quit
        cleanupOrphanASRServer()

        // NOTE: Model size selection is not yet supported by the ASR server.
        // When server adds model selection support, pass settingsManager.modelSize as a CLI argument here.

        // Log paths for debugging
        NSLog("[ASRServer] Project root: %@", Self.projectRoot)
        NSLog("[ASRServer] Python path: %@", Self.pythonPath)
        NSLog("[ASRServer] Server script: %@", Self.serverScriptPath)

        // Verify python executable exists
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: Self.pythonPath) else {
            NSLog("[ASRServer] ERROR: Python executable not found at: %@", Self.pythonPath)
            NSLog("[ASRServer] Please ensure virtual environment is activated or VOICEFLOW_PYTHON is set")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: Self.pythonPath)
        process.arguments = [Self.serverScriptPath]

        // Capture stderr to see error messages
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice

        // Read errors asynchronously
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                NSLog("[ASRServer] stderr: %@", output.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }

        do {
            try process.run()
            asrServerProcess = process
            NSLog("[ASRServer] Started (PID: %d)", process.processIdentifier)

            // Write PID file for cleanup on next launch if crash occurs
            writeASRServerPID(process.processIdentifier)

            // Monitor process termination
            process.terminationHandler = { proc in
                NSLog("[ASRServer] Process terminated with code: %d", proc.terminationStatus)
            }
        } catch {
            NSLog("[ASRServer] Failed to start: %@", error.localizedDescription)
        }
    }

    private func stopASRServer() {
        guard let process = asrServerProcess, process.isRunning else {
            removeASRServerPIDFile()
            return
        }
        process.terminate()
        process.waitUntilExit()
        NSLog("[ASRServer] Stopped")
        asrServerProcess = nil
        removeASRServerPIDFile()
    }

    private func setupSignalHandlers() {
        // Handle SIGINT (Ctrl+C) and SIGTERM to properly terminate Python subprocess
        let signalCallback: @convention(c) (Int32) -> Void = { signal in
            // Terminate Python process
            if let process = (NSApp.delegate as? AppDelegate)?.asrServerProcess, process.isRunning {
                process.terminate()
            }
            // Exit the app
            exit(0)
        }

        signal(SIGINT, signalCallback)
        signal(SIGTERM, signalCallback)
    }

    // MARK: - Sounds

    private func loadSounds() {
        let startURL = URL(fileURLWithPath: "/System/Library/Sounds/Tink.aiff")
        let stopURL = URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")

        var status = AudioServicesCreateSystemSoundID(startURL as CFURL, &startSoundID)
        if status == noErr {
            NSLog("[Audio] startSound loaded via AudioServices (ID: %d)", startSoundID)
        } else {
            NSLog("[Audio] ERROR: Failed to load startSound (status: %d)", status)
        }

        status = AudioServicesCreateSystemSoundID(stopURL as CFURL, &stopSoundID)
        if status == noErr {
            NSLog("[Audio] stopSound loaded via AudioServices (ID: %d)", stopSoundID)
        } else {
            NSLog("[Audio] ERROR: Failed to load stopSound (status: %d)", status)
        }
    }

    private func playSound(_ soundID: SystemSoundID, name: String) {
        // Check if sound effects are enabled
        guard SettingsManager.shared.soundEffectsEnabled else {
            NSLog("[Audio] %@ skipped (sound effects disabled)", name)
            return
        }

        guard soundID != 0 else {
            NSLog("[Audio] WARNING: %@ not loaded, cannot play", name)
            return
        }
        AudioServicesPlaySystemSound(soundID)
        NSLog("[Audio] %@ played via AudioServices", name)
    }

    // MARK: - Onboarding

    private func showOnboarding() {
        NSLog("[Onboarding] Showing onboarding wizard (first launch)")
        onboardingWindow = OnboardingWindow()
        onboardingWindow?.show { [weak self] in
            guard let self = self else { return }
            NSLog("[Onboarding] Wizard completed, marking onboarding as complete")
            self.settingsManager.hasCompletedOnboarding = true
            self.onboardingWindow = nil
        }
    }

    // MARK: - Recording

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        // Check if voice recognition is enabled
        guard SettingsManager.shared.voiceEnabled else {
            NSLog("[Recording] Voice recognition is disabled")
            showVoiceDisabledAlert()
            return
        }

        isRecording = true
        recordingStartTime = Date()
        NSLog("[Recording] Starting recording, playing start sound")
        playSound(startSoundID, name: "startSound")
        overlayPanel.showRecording()
        statusBarController.updateStatus(.recording)

        // 修复时序：先发送 start 消息，等待后再启动录音
        let config = asrManager.buildSessionConfig(mode: .voiceInput)
        asrManager.activeBackend.startSession(config: config) { [weak self] in
            self?.audioRecorder.startRecording {
                NSLog("[Recording] Audio capture fully started after start message sent")
            }
        }
    }

    private func showVoiceDisabledAlert() {
        let alert = NSAlert()
        alert.messageText = localizedString("Voice Recognition Disabled", language: SettingsManager.shared.language)
        alert.informativeText = localizedString("Please enable voice recognition in Settings to use this feature.", language: SettingsManager.shared.language)
        alert.alertStyle = .informational
        alert.addButton(withTitle: localizedString("OK", language: SettingsManager.shared.language))
        alert.runModal()
    }

    private func localizedString(_ key: String, language: String) -> String {
        switch language {
        case "ko":
            switch key {
            case "Voice Recognition Disabled": return "음성 인식 비활성화됨"
            case "Please enable voice recognition in Settings to use this feature.": return "이 기능을 사용하려면 설정에서 음성 인식을 활성화하세요."
            case "OK": return "확인"
            default: return key
            }
        case "zh":
            switch key {
            case "Voice Recognition Disabled": return "语音识别已禁用"
            case "Please enable voice recognition in Settings to use this feature.": return "请在设置中启用语音识别以使用此功能。"
            case "OK": return "确定"
            default: return key
            }
        default: // "en"
            return key
        }
    }

    private func stopRecording() {
        isRecording = false
        NSLog("[Recording] Stopping recording, playing stop sound")
        playSound(stopSoundID, name: "stopSound")
        audioRecorder.disableSilenceDetection()  // 停止时禁用静音检测
        overlayPanel.showProcessing()
        overlayPanel.setFreeSpeakMode(false)  // 退出自由说话模式
        statusBarController.updateStatus(.processing)

        // 修复时序：停止录音 → 等待音频发送完成 → 发送 stop
        audioRecorder.stopRecording { [weak self] in
            self?.asrManager.activeBackend.flushAndStop {
                NSLog("[Recording] Stop sent after all audio flushed")
            }
        }
    }

    /// 自由说话模式：开始录音（启用静音自动停止）
    private func startRecordingFreeSpeak() {
        guard SettingsManager.shared.voiceEnabled else {
            NSLog("[Recording] Voice recognition is disabled")
            showVoiceDisabledAlert()
            return
        }

        isRecording = true
        recordingStartTime = Date()
        NSLog("[Recording] Starting free speak recording with silence detection")
        playSound(startSoundID, name: "startSound")
        overlayPanel.showRecording(partialText: "")
        overlayPanel.setFreeSpeakMode(true)  // 启用自由说话模式显示
        statusBarController.updateStatus(.recording)

        let config = asrManager.buildSessionConfig(mode: .voiceInput)
        asrManager.activeBackend.startSession(config: config)

        audioRecorder.enableSilenceDetection(threshold: 0.005, duration: 2.0)
        audioRecorder.startRecording()
    }

    // MARK: - System Audio Recording

    /// 切换系统音频录制状态
    private func toggleSystemAudioRecording() {
        if isSystemAudioRecording {
            stopSystemAudioRecording()
        } else {
            startSystemAudioRecording()
        }
    }

    /// 本地日志写入文件（NSLog 被系统过滤，用文件确保可见）
    private func debugLog(_ message: String) {
        FileLogger.shared.log(message, to: "system_audio.log")
    }

    /// 开始系统音频录制
    private func startSystemAudioRecording() {
        debugLog("startSystemAudioRecording called, isRecording=\(isRecording), isSystemAudioRecording=\(isSystemAudioRecording)")

        // 检查是否正在麦克风录音
        guard !isRecording else {
            debugLog("BLOCKED: microphone recording in progress")
            return
        }

        // 防止重复启动
        guard !isSystemAudioRecording else {
            debugLog("BLOCKED: already starting or recording")
            return
        }

        debugLog("Starting system audio recording...")

        // 立即设置标志，防止异步操作期间重复触发
        self.isSystemAudioRecording = true
        self.systemAudioStartTime = Date()

        // 显示字幕面板（录制模式，不自动隐藏）
        self.subtitlePanel.showRecording()
        self.statusBarController.updateStatus(.systemAudioRecording)

        // 初始化 BlackHole 录制器
        self.initializeSystemAudioRecorder()
    }

    private func initializeSystemAudioRecorder() {
        debugLog("initializeSystemAudioRecorder called")

        // 创建 SystemAudioRecorder
        let recorder = SystemAudioRecorder()
        self.systemAudioRecorder = recorder

        // 用一个标识符追踪当前录制会话，防止旧回调影响新会话
        let sessionID = UUID()
        let currentSessionID = sessionID

        // 音频数据回调 → 发送到 ASR
        var chunkCount = 0
        recorder.onAudioChunk = { [weak self] data in
            chunkCount += 1
            if chunkCount <= 5 || chunkCount % 50 == 0 {
                self?.debugLog("onAudioChunk #\(chunkCount), size=\(data.count)")
            }
            self?.asrManager.activeBackend.feedAudioChunk(data)
        }

        // 音量回调 → 系统音频不需要显示音量
        recorder.onVolumeLevel = { _ in }

        // 错误回调 — 只有当前会话的错误才停止录制
        recorder.onError = { [weak self] error in
            self?.debugLog("ERROR (session=\(currentSessionID.uuidString.prefix(8))): \(error.localizedDescription)")
            // 不自动停止，只记录错误；权限错误不应杀死整个会话
        }

        // 检查 ASR 连接状态 (Native 模式始终就绪，WebSocket 需要检查连接)
        guard self.asrManager.activeBackend.isReady else {
            debugLog("BLOCKED: ASR not ready (backend: \(self.asrManager.backendType.rawValue))")
            self.isSystemAudioRecording = false
            self.systemAudioStartTime = nil
            self.subtitlePanel.hide()
            self.statusBarController.updateStatus(.idle)
            return
        }

        debugLog("ASR ready (backend: \(self.asrManager.backendType.rawValue)), sending start and beginning recording")
        self.playSound(self.startSoundID, name: "startSound")
        self.statusBarController.updateSystemAudioRecordingStatus(recording: true)

        // 发送 ASR 开始消息（字幕模式，启用定时转录）
        let config = asrManager.buildSessionConfig(mode: .subtitle)
        self.asrManager.activeBackend.startSession(config: config)

        // 直接开始录制（跳过 prepare，权限由 startRecording 内部处理）
        recorder.startRecording { [weak self] success in
            self?.debugLog("startRecording completion: success=\(success)")
            guard let self = self else { return }
            if !success {
                self.debugLog("startRecording failed, will retry after requesting permission")
                DispatchQueue.main.async {
                    // 录制失败时重置状态，不调用 stopSystemAudioRecording 避免发送无效的 stop
                    self.isSystemAudioRecording = false
                    self.systemAudioStartTime = nil
                    self.subtitlePanel.hide()
                    self.statusBarController.updateStatus(.idle)
                    self.statusBarController.updateSystemAudioRecordingStatus(recording: false)
                    self.systemAudioRecorder = nil
                }
            }
        }
    }

    /// 停止系统音频录制
    private func stopSystemAudioRecording() {
        guard isSystemAudioRecording else { return }

        NSLog("[SystemAudio] Stopping system audio recording...")
        // 注意：不要在这里设置 isSystemAudioRecording = false
        // 必须等 ASR 返回 final 结果后再重置，否则 onTranscriptionResult 会丢弃结果
        playSound(stopSoundID, name: "stopSound")
        statusBarController.updateStatus(.processing)
        statusBarController.updateSystemAudioRecordingStatus(recording: false)

        // 停止录制
        systemAudioRecorder?.stopRecording { [weak self] in
            guard let self = self else { return }

            // 发送 ASR 停止消息
            self.asrManager.activeBackend.flushAndStop {
                NSLog("[SystemAudio] Stop sent after all audio flushed")
                // flushAndStop 完成后，等待 final 结果返回
                // 设置一个超时：5秒后如果还没收到结果，强制重置状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if self.isSystemAudioRecording {
                        NSLog("[SystemAudio] Timeout waiting for final result, resetting state")
                        self.isSystemAudioRecording = false
                        self.subtitlePanel.stopRecording()
                        self.statusBarController.updateStatus(.idle)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                            self.subtitlePanel.hide()
                        }
                    }
                }
            }

            // 保存转录结果
            if let startTime = self.systemAudioStartTime {
                let duration = Date().timeIntervalSince(startTime)
                // 从字幕面板获取所有已确认字幕，合并为一条完整记录
                let subtitles = self.subtitlePanel.getAllSubtitles()
                let fullText = subtitles.joined(separator: "\n")
                if !fullText.isEmpty {
                    // 获取当前活跃应用名称
                    let frontmostApp = NSWorkspace.shared.frontmostApplication
                    let appName = frontmostApp?.localizedName
                    TranscriptStorage.shared.saveTranscript(
                        text: fullText,
                        timestamp: startTime,
                        duration: duration,
                        appName: appName
                    )
                }
                self.systemAudioStartTime = nil
            }

            self.systemAudioRecorder = nil
        }
    }
}
