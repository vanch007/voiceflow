import AppKit

enum AppStatus {
    case idle
    case recording
    case processing
    case error
}

private enum IconStyle: String {
    case colored
    case monochrome
}

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onSettings: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onTextReplacement: (() -> Void)?
    var onDeviceSelected: ((String?) -> Void)?  // nil = system default
    var onHotkeySettings: (() -> Void)?
    var onSceneSettings: (() -> Void)?

    private let statusItem: NSStatusItem
    private var isConnected = false
    private var isRecording = false
    private var activeDeviceName: String?
    private var currentStatus: AppStatus = .idle
    private var errorMessage: String?
    private var debounceTimer: Timer?
    private let errorDebounceInterval: TimeInterval = 3.0
    private var lastCheckTime: Date = Date()
    private var sceneObserver: Any?
    private var permissionAlertWindow: PermissionAlertWindow!

    private var iconStyle: IconStyle {
        get {
            let raw = UserDefaults.standard.string(forKey: "iconStyle") ?? "colored"
            return IconStyle(rawValue: raw) ?? .colored
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "iconStyle")
            updateIcon()  // Apply immediately
            updateTooltip()
        }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        permissionAlertWindow = PermissionAlertWindow()
        updateIcon()
        buildMenu()
        updateTooltip()

        // Observe language changes for real-time menu updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange(_:)),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )

        // Observe scene changes for real-time menu updates
        sceneObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.buildMenu()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = sceneObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Localization Helper

    private func localized(_ key: String) -> String {
        let language = SettingsManager.shared.language
        let strings: [String: [String: String]] = [
            "asr_connected": [
                "ko": "ASR 서버: 연결됨",
                "en": "ASR Server: Connected",
                "zh": "ASR 服务器：已连接"
            ],
            "asr_disconnected": [
                "ko": "ASR 서버: 끊어짐",
                "en": "ASR Server: Disconnected",
                "zh": "ASR 服务器：已断开"
            ],
            "system_default": [
                "ko": "시스템 기본값",
                "en": "System Default",
                "zh": "系统默认"
            ],
            "microphone": [
                "ko": "마이크",
                "en": "Microphone",
                "zh": "麦克风"
            ],
            "settings": [
                "ko": "설정...",
                "en": "Settings...",
                "zh": "设置..."
            ],
            "hotkey_settings": [
                "ko": "단축키 설정...",
                "en": "Hotkey Settings...",
                "zh": "快捷键设置..."
            ],
            "quit": [
                "ko": "종료",
                "en": "Quit",
                "zh": "退出"
            ],
            "plugins": [
                "ko": "플러그인",
                "en": "Plugins",
                "zh": "插件"
            ],
            "no_plugins": [
                "ko": "플러그인 없음",
                "en": "No Plugins",
                "zh": "无插件"
            ],
            "model_info": [
                "ko": "모델: Qwen3-ASR-0.6B (MLX)",
                "en": "Model: Qwen3-ASR-0.6B (MLX)",
                "zh": "模型: Qwen3-ASR-0.6B (MLX)"
            ],
            "recording_history": [
                "ko": "녹음 기록",
                "en": "Recording History",
                "zh": "录音记录"
            ],
            "text_replacement": [
                "ko": "텍스트 대체...",
                "en": "Text Replacement...",
                "zh": "文本替换..."
            ],
            "icon_style": [
                "ko": "아이콘 스타일",
                "en": "Icon Style",
                "zh": "图标样式"
            ],
            "colored": [
                "ko": "컬러",
                "en": "Colored",
                "zh": "彩色"
            ],
            "monochrome": [
                "ko": "단색",
                "en": "Monochrome",
                "zh": "单色"
            ],
            "scene": [
                "ko": "장면",
                "en": "Scene",
                "zh": "场景"
            ],
            "scene_auto_detect": [
                "ko": "자동 감지",
                "en": "Auto Detect",
                "zh": "自动检测"
            ],
            "scene_social": [
                "ko": "소셜 채팅",
                "en": "Social Chat",
                "zh": "社交聊天"
            ],
            "scene_coding": [
                "ko": "IDE 코딩",
                "en": "IDE Coding",
                "zh": "IDE编程"
            ],
            "scene_writing": [
                "ko": "글쓰기",
                "en": "Writing",
                "zh": "写作"
            ],
            "scene_general": [
                "ko": "일반",
                "en": "General",
                "zh": "通用"
            ],
            "scene_settings": [
                "ko": "장면 설정...",
                "en": "Scene Settings...",
                "zh": "场景设置..."
            ],
            "check_permissions": [
                "ko": "권한 확인...",
                "en": "Check Permissions...",
                "zh": "权限检查..."
            ],
            "text_polish": [
                "ko": "AI 교정",
                "en": "AI Correction",
                "zh": "AI 纠错"
            ],
            "timestamps": [
                "ko": "타임스탬프 분할",
                "en": "Timestamp Segmentation",
                "zh": "时间戳断句"
            ],
            "denoise": [
                "ko": "실시간 노이즈 제거",
                "en": "Real-time Denoise",
                "zh": "实时降噪"
            ],
            "language": [
                "ko": "언어",
                "en": "Language",
                "zh": "语言"
            ],
            "more_languages": [
                "ko": "더 많은 언어...",
                "en": "More Languages...",
                "zh": "更多语言..."
            ]
        ]

        return strings[key]?[language] ?? strings[key]?["zh"] ?? key
    }

    @objc private func handleLanguageChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let category = userInfo["category"] as? String,
              let key = userInfo["key"] as? String else {
            return
        }

        // Rebuild menu when language changes
        if category == "general" && key == "language" {
            buildMenu()
        }
    }

    func updateConnectionStatus(connected: Bool) {
        isConnected = connected
        lastCheckTime = Date()
        buildMenu()
        updateTooltip()
    }

    func updateRecordingStatus(recording: Bool) {
        isRecording = recording
        updateIcon()
    }

    func updateActiveDevice(name: String) {
        activeDeviceName = name
        buildMenu()
    }

    func updateStatus(_ status: AppStatus) {
        // Cancel any pending debounced transition
        stopDebounceTimer()

        // For error state, debounce the transition
        if status == .error {
            startDebounceTimer(targetStatus: status)
        } else {
            // Immediate transition for non-error states
            currentStatus = status
            errorMessage = nil
            updateIcon()
            updateTooltip()
        }
    }

    func updateErrorState(hasError: Bool, message: String?) {
        if hasError {
            errorMessage = message
            updateStatus(.error)
        } else {
            errorMessage = nil
            updateStatus(.idle)
        }
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }

        let symbolName: String
        let baseColor: NSColor

        switch currentStatus {
        case .idle:
            symbolName = "mic"
            baseColor = .systemGray
        case .recording:
            symbolName = "mic.fill"
            baseColor = .systemRed
        case .processing:
            symbolName = "waveform"
            baseColor = .systemBlue
        case .error:
            symbolName = "exclamationmark.triangle"
            baseColor = .systemOrange
        }

        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "VoiceFlow - \(currentStatus)")

        // Apply color based on style preference
        if iconStyle == .monochrome {
            button.contentTintColor = .systemGray
        } else {
            button.contentTintColor = baseColor
        }
    }

    private func updateTooltip() {
        guard let button = statusItem.button else { return }

        // Build localized tooltip content
        let appStateText: String
        switch currentStatus {
        case .idle:
            appStateText = "대기 중"
        case .recording:
            appStateText = "녹음 중"
        case .processing:
            appStateText = "처리 중"
        case .error:
            appStateText = "오류"
        }

        let asrStatusText = isConnected ? "연결됨" : "끊어짐"

        // Format timestamp in localized format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        dateFormatter.locale = Locale(identifier: "ko_KR")
        let lastCheckText = dateFormatter.string(from: lastCheckTime)

        // Build tooltip
        var tooltip = """
        앱 상태: \(appStateText)
        ASR 상태: \(asrStatusText)
        마지막 확인: \(lastCheckText)
        """

        // Add error message if present
        if let errorMsg = errorMessage {
            tooltip += "\n오류 메시지: \(errorMsg)"
        }

        button.toolTip = tooltip
    }

    private func startDebounceTimer(targetStatus: AppStatus) {
        debounceTimer = Timer.scheduledTimer(withTimeInterval: errorDebounceInterval, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.currentStatus = targetStatus
            self.updateIcon()
            self.updateTooltip()
        }
    }

    private func stopDebounceTimer() {
        debounceTimer?.invalidate()
        debounceTimer = nil
    }

    private func buildMenu() {
        let menu = NSMenu()

        // ASR server status
        let statusTitle = isConnected ? localized("asr_connected") : localized("asr_disconnected")
        let connItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        connItem.isEnabled = false
        let statusImage = NSImage(
            systemSymbolName: isConnected ? "circle.fill" : "circle",
            accessibilityDescription: nil
        )
        statusImage?.isTemplate = false
        if isConnected {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
            connItem.image = statusImage?.withSymbolConfiguration(config)
        } else {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            connItem.image = statusImage?.withSymbolConfiguration(config)
        }
        menu.addItem(connItem)

        menu.addItem(NSMenuItem.separator())

        // AI 纠错 Toggle (使用 llmSettings.isEnabled)
        let polishItem = NSMenuItem(title: localized("text_polish"), action: #selector(toggleTextPolish), keyEquivalent: "")
        polishItem.target = self
        polishItem.state = SettingsManager.shared.llmSettings.isEnabled ? .on : .off
        polishItem.image = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)
        menu.addItem(polishItem)

        // Timestamp Segmentation Toggle
        let timestampItem = NSMenuItem(title: localized("timestamps"), action: #selector(toggleTimestamps), keyEquivalent: "")
        timestampItem.target = self
        timestampItem.state = SettingsManager.shared.useTimestamps ? .on : .off
        timestampItem.image = NSImage(systemSymbolName: "clock", accessibilityDescription: nil)
        menu.addItem(timestampItem)

        // Denoise Toggle
        let denoiseItem = NSMenuItem(title: localized("denoise"), action: #selector(toggleDenoise), keyEquivalent: "")
        denoiseItem.target = self
        denoiseItem.state = SettingsManager.shared.enableDenoise ? .on : .off
        denoiseItem.image = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil)
        menu.addItem(denoiseItem)

        menu.addItem(NSMenuItem.separator())

        // Language quick switch submenu
        let languageSubmenu = buildLanguageSubmenu()
        let currentLang = SettingsManager.shared.asrLanguage
        let languageTitle = "\(localized("language")): \(currentLang.displayName)"
        let languageItem = NSMenuItem(title: languageTitle, action: nil, keyEquivalent: "")
        languageItem.image = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)
        languageItem.submenu = languageSubmenu
        menu.addItem(languageItem)

        // Scene selection submenu
        let sceneSubmenu = NSMenu()
        let sceneManager = SceneManager.shared

        // Auto detect option
        let autoDetectItem = NSMenuItem(title: localized("scene_auto_detect"), action: #selector(selectAutoDetectScene), keyEquivalent: "")
        autoDetectItem.target = self
        autoDetectItem.state = sceneManager.isAutoDetectEnabled ? .on : .off
        sceneSubmenu.addItem(autoDetectItem)
        sceneSubmenu.addItem(NSMenuItem.separator())

        // Scene type options
        for sceneType in SceneType.allCases {
            let item = NSMenuItem(title: localizedSceneName(sceneType), action: #selector(selectScene(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = sceneType.rawValue
            item.image = NSImage(systemSymbolName: sceneType.icon, accessibilityDescription: nil)
            if !sceneManager.isAutoDetectEnabled && sceneManager.manualOverride == sceneType {
                item.state = .on
            } else if sceneManager.isAutoDetectEnabled && sceneManager.currentScene == sceneType {
                // Show current auto-detected scene with a different indicator
                item.state = .mixed
            }
            sceneSubmenu.addItem(item)
        }

        sceneSubmenu.addItem(NSMenuItem.separator())

        // Scene settings
        let sceneSettingsItem = NSMenuItem(title: localized("scene_settings"), action: #selector(sceneSettingsAction), keyEquivalent: "")
        sceneSettingsItem.target = self
        sceneSubmenu.addItem(sceneSettingsItem)

        let currentScene = sceneManager.manualOverride ?? sceneManager.currentScene
        let sceneTitle = "\(localized("scene")): \(localizedSceneName(currentScene))"
        let sceneItem = NSMenuItem(title: sceneTitle, action: nil, keyEquivalent: "")
        sceneItem.image = NSImage(systemSymbolName: currentScene.icon, accessibilityDescription: nil)
        sceneItem.submenu = sceneSubmenu
        menu.addItem(sceneItem)

        menu.addItem(NSMenuItem.separator())

        // Microphone selection submenu
        let micSubmenu = NSMenu()
        let devices = AudioRecorder.availableDevices()

        // "System Default" option
        let defaultItem = NSMenuItem(title: localized("system_default"), action: #selector(selectDefaultDevice), keyEquivalent: "")
        defaultItem.target = self
        // Check if no device is explicitly selected (using default)
        if UserDefaults.standard.string(forKey: "selectedAudioDevice") == nil {
            defaultItem.state = .on
        }
        micSubmenu.addItem(defaultItem)
        micSubmenu.addItem(NSMenuItem.separator())

        for device in devices {
            let item = NSMenuItem(title: device.name, action: #selector(selectDevice(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = device.id
            if device.id == UserDefaults.standard.string(forKey: "selectedAudioDevice") {
                item.state = .on
            }
            micSubmenu.addItem(item)
        }

        let micBaseTitle = localized("microphone")
        let micItem = NSMenuItem(title: micBaseTitle, action: nil, keyEquivalent: "")
        micItem.image = NSImage(systemSymbolName: "mic.badge.plus", accessibilityDescription: nil)
        if let name = activeDeviceName {
            micItem.title = "\(micBaseTitle): \(name)"
        }
        micItem.submenu = micSubmenu
        menu.addItem(micItem)

        menu.addItem(NSMenuItem.separator())

        // Icon style selection submenu
        let styleItem = NSMenuItem(title: localized("icon_style"), action: nil, keyEquivalent: "")
        styleItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)

        let styleSubmenu = NSMenu()

        let coloredItem = NSMenuItem(title: localized("colored"), action: #selector(selectColoredStyle), keyEquivalent: "")
        coloredItem.target = self
        coloredItem.state = iconStyle == .colored ? .on : .off
        styleSubmenu.addItem(coloredItem)

        let monoItem = NSMenuItem(title: localized("monochrome"), action: #selector(selectMonochromeStyle), keyEquivalent: "")
        monoItem.target = self
        monoItem.state = iconStyle == .monochrome ? .on : .off
        styleSubmenu.addItem(monoItem)

        styleItem.submenu = styleSubmenu
        menu.addItem(styleItem)

        menu.addItem(NSMenuItem.separator())

        // Plugins submenu
        let pluginsSubmenu = NSMenu()
        let plugins = PluginManager.shared.getAllPlugins()

        if plugins.isEmpty {
            let emptyItem = NSMenuItem(title: localized("no_plugins"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            pluginsSubmenu.addItem(emptyItem)
        } else {
            for plugin in plugins {
                let item = NSMenuItem(title: plugin.manifest.name, action: #selector(togglePlugin(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = plugin.manifest.id
                if plugin.isEnabled {
                    item.state = .on
                }
                pluginsSubmenu.addItem(item)
            }
        }

        let pluginsItem = NSMenuItem(title: localized("plugins"), action: nil, keyEquivalent: "")
        pluginsItem.image = NSImage(systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
        pluginsItem.submenu = pluginsSubmenu
        menu.addItem(pluginsItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: localized("recording_history"), action: #selector(showHistoryAction), keyEquivalent: "h")
        historyItem.target = self
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: localized("settings"), action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: localized("quit"), action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func settingsAction() {
        onSettings?()
    }

    @objc private func hotkeySettingsAction() {
        onHotkeySettings?()
    }

    @objc private func textReplacementAction() {
        onTextReplacement?()
    }

    @objc private func showHistoryAction() {
        onShowHistory?()
    }

    @objc private func selectDefaultDevice() {
        UserDefaults.standard.removeObject(forKey: "selectedAudioDevice")
        onDeviceSelected?(nil)
        buildMenu()
    }

    @objc private func selectDevice(_ sender: NSMenuItem) {
        guard let deviceID = sender.representedObject as? String else { return }
        UserDefaults.standard.set(deviceID, forKey: "selectedAudioDevice")
        onDeviceSelected?(deviceID)
        buildMenu()
    }

    @objc private func togglePlugin(_ sender: NSMenuItem) {
        guard let pluginID = sender.representedObject as? String else { return }

        if let plugin = PluginManager.shared.getPlugin(pluginID) {
            if plugin.isEnabled {
                PluginManager.shared.disablePlugin(pluginID)
            } else {
                PluginManager.shared.enablePlugin(pluginID)
            }
        }

        buildMenu()
    }

    @objc private func selectColoredStyle() {
        iconStyle = .colored
        buildMenu()  // Refresh checkmarks
    }

    @objc private func selectMonochromeStyle() {
        iconStyle = .monochrome
        buildMenu()  // Refresh checkmarks
    }

    @objc private func checkPermissionsAction() {
        permissionAlertWindow.show()
    }

    @objc private func quitAction() {
        onQuit?()
    }

    // MARK: - Scene Actions

    @objc private func selectAutoDetectScene() {
        SceneManager.shared.setManualScene(nil)
        buildMenu()
    }

    @objc private func selectScene(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let sceneType = SceneType(rawValue: rawValue) else { return }
        SceneManager.shared.setManualScene(sceneType)
        buildMenu()
    }

    @objc private func sceneSettingsAction() {
        onSceneSettings?()
    }

    // MARK: - Language Actions

    private func buildLanguageSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let currentLang = SettingsManager.shared.asrLanguage

        // Common languages (top 6)
        let commonLanguages: [ASRLanguage] = [.auto, .chinese, .english, .cantonese, .japanese, .korean]

        for lang in commonLanguages {
            let item = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.rawValue
            item.state = (currentLang == lang) ? .on : .off
            submenu.addItem(item)
        }

        submenu.addItem(NSMenuItem.separator())

        // "More Languages..." entry -> opens settings
        let moreItem = NSMenuItem(title: localized("more_languages"), action: #selector(settingsAction), keyEquivalent: "")
        moreItem.target = self
        submenu.addItem(moreItem)

        return submenu
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let language = ASRLanguage(rawValue: rawValue) else { return }
        SettingsManager.shared.asrLanguage = language
        buildMenu()
    }

    // MARK: - Toggle Actions

    @objc private func toggleTextPolish() {
        var settings = SettingsManager.shared.llmSettings
        settings.isEnabled.toggle()
        SettingsManager.shared.llmSettings = settings
        buildMenu()
    }

    @objc private func toggleTimestamps() {
        SettingsManager.shared.useTimestamps.toggle()
        buildMenu()
    }

    @objc private func toggleDenoise() {
        SettingsManager.shared.enableDenoise.toggle()
        buildMenu()
    }

    private func localizedSceneName(_ sceneType: SceneType) -> String {
        switch sceneType {
        case .social: return localized("scene_social")
        case .coding: return localized("scene_coding")
        case .writing: return localized("scene_writing")
        case .general: return localized("scene_general")
        case .medical, .legal, .technical, .finance, .engineering:
            return sceneType.displayName
        }
    }
}
