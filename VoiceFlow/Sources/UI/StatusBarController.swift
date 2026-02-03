import AppKit

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onSettings: (() -> Void)?
    var onDeviceSelected: ((String?) -> Void)?  // nil = system default

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
            "quit": [
                "ko": "종료",
                "en": "Quit",
                "zh": "退出"
            ]
        ]

        return strings[key]?[language] ?? strings[key]?["ko"] ?? key
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

        let settingsItem = NSMenuItem(title: localized("settings"), action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: localized("quit"), action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
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

    @objc private func settingsAction() {
        onSettings?()
    }

    @objc private func quitAction() {
        onQuit?()
    }
}
