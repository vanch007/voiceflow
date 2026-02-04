import AppKit

enum AppStatus {
    case idle
    case recording
    case processing
    case error
}

final class StatusBarController {
    var onQuit: (() -> Void)?
    var onDeviceSelected: ((String?) -> Void)?  // nil = system default

    private let statusItem: NSStatusItem
    private var isConnected = false
    private var isRecording = false
    private var activeDeviceName: String?
    private var currentStatus: AppStatus = .idle
    private var errorMessage: String?
    private var debounceTimer: Timer?
    private let errorDebounceInterval: TimeInterval = 3.0
    private var lastCheckTime: Date = Date()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        buildMenu()
        updateTooltip()
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

        switch currentStatus {
        case .idle:
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "VoiceFlow - Idle")
            button.contentTintColor = .systemGray
        case .recording:
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceFlow - Recording")
            button.contentTintColor = .systemRed
        case .processing:
            button.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "VoiceFlow - Processing")
            button.contentTintColor = .systemBlue
        case .error:
            button.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "VoiceFlow - Error")
            button.contentTintColor = .systemOrange
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
        let statusTitle = isConnected ? "ASR 서버: 연결됨" : "ASR 서버: 끊어짐"
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
        let defaultItem = NSMenuItem(title: "시스템 기본값", action: #selector(selectDefaultDevice), keyEquivalent: "")
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

        let micItem = NSMenuItem(title: "마이크", action: nil, keyEquivalent: "")
        micItem.image = NSImage(systemSymbolName: "mic.badge.plus", accessibilityDescription: nil)
        if let name = activeDeviceName {
            micItem.title = "마이크: \(name)"
        }
        micItem.submenu = micSubmenu
        menu.addItem(micItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "종료", action: #selector(quitAction), keyEquivalent: "q")
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

    @objc private func quitAction() {
        onQuit?()
    }
}
