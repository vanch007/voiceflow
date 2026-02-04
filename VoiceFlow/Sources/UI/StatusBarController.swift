import AppKit

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onSettings: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onTextReplacement: (() -> Void)?
    var onDeviceSelected: ((String?) -> Void)?  // nil = system default
    var onDictionaryOpen: (() -> Void)?
    var onHotkeySettings: (() -> Void)?

    private let statusItem: NSStatusItem
    private var isConnected = false
    private var isRecording = false
    private var activeDeviceName: String?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()

        // Observe language changes for real-time menu updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange(_:)),
            name: SettingsManager.settingsDidChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
            "dictionary": [
                "ko": "사용자 사전",
                "en": "Custom Dictionary",
                "zh": "自定义词典"
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
        buildMenu()
    }

    func updateRecordingStatus(recording: Bool) {
        isRecording = recording
        updateIcon()
    }

    func updateActiveDevice(name: String) {
        activeDeviceName = name
        buildMenu()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        if isRecording {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceFlow - Recording")
            button.contentTintColor = .systemRed
        } else {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "VoiceFlow")
            button.contentTintColor = nil
        }
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

        // Custom Dictionary menu item
        let dictItem = NSMenuItem(title: localized("dictionary"), action: #selector(openDictionary), keyEquivalent: "")
        dictItem.target = self
        dictItem.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: nil)
        menu.addItem(dictItem)

        menu.addItem(NSMenuItem.separator())

        // 模型信息（MLX版本只支持一个模型）
        let modelInfoItem = NSMenuItem(title: localized("model_info"), action: nil, keyEquivalent: "")
        modelInfoItem.isEnabled = false
        menu.addItem(modelInfoItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: localized("recording_history"), action: #selector(showHistoryAction), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: localized("settings"), action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let hotkeySettingsItem = NSMenuItem(title: localized("hotkey_settings"), action: #selector(hotkeySettingsAction), keyEquivalent: "")
        hotkeySettingsItem.target = self
        menu.addItem(hotkeySettingsItem)

        let textReplacementItem = NSMenuItem(title: localized("text_replacement"), action: #selector(textReplacementAction), keyEquivalent: "")
        textReplacementItem.target = self
        menu.addItem(textReplacementItem)

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

    @objc private func openDictionary() {
        onDictionaryOpen?()
    }

    @objc private func quitAction() {
        onQuit?()
    }
}
