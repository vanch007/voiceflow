import AppKit

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onModelChange: ((String) -> Void)?
    var onSettings: (() -> Void)?
    var onShowHistory: (() -> Void)?

    private let statusItem: NSStatusItem
    private var isConnected = false
    private var isRecording = false
    private var currentModel = "1.7B"  // 默认模型

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
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        let statusImage = NSImage(
            systemSymbolName: isConnected ? "circle.fill" : "circle",
            accessibilityDescription: nil
        )
        statusImage?.isTemplate = false
        if isConnected {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
            statusItem.image = statusImage?.withSymbolConfiguration(config)
        } else {
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            statusItem.image = statusImage?.withSymbolConfiguration(config)
        }
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // 模型选择子菜单
        let modelMenu = NSMenu()

        let model17Item = NSMenuItem(title: "Qwen3-ASR-1.7B (推荐)", action: #selector(selectModel17B), keyEquivalent: "")
        model17Item.target = self
        model17Item.state = currentModel == "1.7B" ? .on : .off
        modelMenu.addItem(model17Item)

        let model06Item = NSMenuItem(title: "Qwen3-ASR-0.6B (快速)", action: #selector(selectModel06B), keyEquivalent: "")
        model06Item.target = self
        model06Item.state = currentModel == "0.6B" ? .on : .off
        modelMenu.addItem(model06Item)

        let modelMenuItem = NSMenuItem(title: "选择模型", action: nil, keyEquivalent: "")
        modelMenuItem.submenu = modelMenu
        menu.addItem(modelMenuItem)

        menu.addItem(NSMenuItem.separator())

        let historyItem = NSMenuItem(title: "录音记录", action: #selector(showHistoryAction), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "设置", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func selectModel17B() {
        changeModel("1.7B")
    }

    @objc private func selectModel06B() {
        changeModel("0.6B")
    }

    private func changeModel(_ modelSize: String) {
        guard modelSize != currentModel else { return }
        currentModel = modelSize
        buildMenu()  // 重新构建菜单以更新选中状态
        onModelChange?(modelSize)
    }

    @objc private func settingsAction() {
        onSettings?()
    }

    @objc private func showHistoryAction() {
        onShowHistory?()
    }

    @objc private func quitAction() {
        onQuit?()
    }
}
