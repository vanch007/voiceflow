import AppKit

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onSettings: (() -> Void)?
    var onShowHistory: (() -> Void)?
    var onTextReplacement: (() -> Void)?
    var onDeviceSelected: ((String?) -> Void)?  // nil = system default
    var onDictionaryOpen: (() -> Void)?

    private let statusItem: NSStatusItem
    private var isConnected = false
    private var isRecording = false
    private var activeDeviceName: String?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
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

        // ASR 服务器连接状态
        let statusTitle = isConnected ? "ASR 服务器: 已连接" : "ASR 服务器: 已断开"
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
        let defaultItem = NSMenuItem(title: "系统默认", action: #selector(selectDefaultDevice), keyEquivalent: "")
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

        let micItem = NSMenuItem(title: "麦克风", action: nil, keyEquivalent: "")
        micItem.image = NSImage(systemSymbolName: "mic.badge.plus", accessibilityDescription: nil)
        if let name = activeDeviceName {
            micItem.title = "麦克风: \(name)"
        }
        micItem.submenu = micSubmenu
        menu.addItem(micItem)

        menu.addItem(NSMenuItem.separator())

        // Plugins submenu
        let pluginsSubmenu = NSMenu()
        let plugins = PluginManager.shared.getAllPlugins()

        if plugins.isEmpty {
            let emptyItem = NSMenuItem(title: "无插件", action: nil, keyEquivalent: "")
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

        let pluginsItem = NSMenuItem(title: "插件", action: nil, keyEquivalent: "")
        pluginsItem.image = NSImage(systemSymbolName: "puzzlepiece.extension", accessibilityDescription: nil)
        pluginsItem.submenu = pluginsSubmenu
        menu.addItem(pluginsItem)

        menu.addItem(NSMenuItem.separator())

        // Custom Dictionary menu item
        let dictItem = NSMenuItem(title: "自定义词典", action: #selector(openDictionary), keyEquivalent: "")
        dictItem.target = self
        dictItem.image = NSImage(systemSymbolName: "book.closed", accessibilityDescription: nil)
        menu.addItem(dictItem)

        menu.addItem(NSMenuItem.separator())

        // 模型信息（MLX版本只支持一个模型）
        let modelInfoItem = NSMenuItem(title: "模型: Qwen3-ASR-0.6B (MLX)", action: nil, keyEquivalent: "")
        modelInfoItem.isEnabled = false
        menu.addItem(modelInfoItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "录音记录", action: #selector(showHistoryAction), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let textReplacementItem = NSMenuItem(title: "文本替换...", action: #selector(textReplacementAction), keyEquivalent: "")
        textReplacementItem.target = self
        menu.addItem(textReplacementItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func settingsAction() {
        onSettings?()
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
