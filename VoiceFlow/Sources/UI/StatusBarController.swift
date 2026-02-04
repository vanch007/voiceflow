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

        // Icon style selection submenu
        let styleItem = NSMenuItem(title: "아이콘 스타일", action: nil, keyEquivalent: "")
        styleItem.image = NSImage(systemSymbolName: "paintpalette", accessibilityDescription: nil)

        let styleSubmenu = NSMenu()

        let coloredItem = NSMenuItem(title: "컬러", action: #selector(selectColoredStyle), keyEquivalent: "")
        coloredItem.target = self
        coloredItem.state = iconStyle == .colored ? .on : .off
        styleSubmenu.addItem(coloredItem)

        let monoItem = NSMenuItem(title: "단색", action: #selector(selectMonochromeStyle), keyEquivalent: "")
        monoItem.target = self
        monoItem.state = iconStyle == .monochrome ? .on : .off
        styleSubmenu.addItem(monoItem)

        styleItem.submenu = styleSubmenu
        menu.addItem(styleItem)

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

    @objc private func selectColoredStyle() {
        iconStyle = .colored
        buildMenu()  // Refresh checkmarks
    }

    @objc private func selectMonochromeStyle() {
        iconStyle = .monochrome
        buildMenu()  // Refresh checkmarks
    }

    @objc private func quitAction() {
        onQuit?()
    }
}
