import AppKit

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onShowHistory: (() -> Void)?

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

        let statusTitle = isConnected ? "ASR 서버: 연결됨" : "ASR 서버: 끊어짐"
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

        let historyItem = NSMenuItem(title: "녹음 기록", action: #selector(showHistoryAction), keyEquivalent: "h")
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func showHistoryAction() {
        onShowHistory?()
    }

    @objc private func quitAction() {
        onQuit?()
    }
}
