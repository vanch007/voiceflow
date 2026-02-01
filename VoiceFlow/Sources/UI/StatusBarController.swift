import AppKit

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onSettings: (() -> Void)?

    private let statusItem: NSStatusItem
    private var isConnected = false
    private var isRecording = false

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

        let statusTitle = isConnected ? "ASR 服务器: 已连接" : "ASR 服务器: 未连接"
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

        let settingsItem = NSMenuItem(title: "设置", action: #selector(settingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "退出", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func settingsAction() {
        onSettings?()
    }

    @objc private func quitAction() {
        onQuit?()
    }
}
