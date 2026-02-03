import AppKit

final class HotkeySettingsWindow: NSWindow {
    var onSave: ((HotkeyConfig) -> Void)?
    var onCancel: (() -> Void)?
    var onReset: (() -> Void)?

    private var currentConfig: HotkeyConfig
    private let hotkeyDisplayField: NSTextField
    private let captureButton: NSButton
    private let presetStackView: NSStackView
    private let restoreDefaultButton: NSButton
    private let cancelButton: NSButton
    private let saveButton: NSButton
    private let warningLabel: NSTextField
    private var isCapturing = false
    private var eventMonitor: Any?
    private var presetConfigs: [Int: HotkeyConfig] = [:]

    init() {
        // Load current config from UserDefaults or use default
        if let savedData = UserDefaults.standard.data(forKey: "voiceflow.hotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) {
            currentConfig = config
        } else {
            currentConfig = HotkeyConfig.default
        }

        // Initialize UI elements
        hotkeyDisplayField = NSTextField(labelWithString: "")
        captureButton = NSButton(title: "录制快捷键...", target: nil, action: nil)
        presetStackView = NSStackView()
        restoreDefaultButton = NSButton(title: "恢复默认", target: nil, action: nil)
        cancelButton = NSButton(title: "取消", target: nil, action: nil)
        saveButton = NSButton(title: "保存", target: nil, action: nil)
        warningLabel = NSTextField(labelWithString: "")

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "快捷键设置"
        self.isReleasedWhenClosed = false
        self.center()

        setupUI()
        updateHotkeyDisplay()
    }

    private func setupUI() {
        let contentView = NSView(frame: self.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        self.contentView = contentView

        // Title label
        let titleLabel = NSTextField(labelWithString: "自定义触发快捷键")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Hotkey display field
        hotkeyDisplayField.isEditable = false
        hotkeyDisplayField.isBordered = true
        hotkeyDisplayField.bezelStyle = .roundedBezel
        hotkeyDisplayField.alignment = .center
        hotkeyDisplayField.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        hotkeyDisplayField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hotkeyDisplayField)

        // Capture button
        captureButton.target = self
        captureButton.action = #selector(startCapture)
        captureButton.bezelStyle = .rounded
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(captureButton)

        // Warning label
        warningLabel.isEditable = false
        warningLabel.isBordered = false
        warningLabel.drawsBackground = false
        warningLabel.textColor = .systemOrange
        warningLabel.font = NSFont.systemFont(ofSize: 11)
        warningLabel.alignment = .center
        warningLabel.lineBreakMode = .byWordWrapping
        warningLabel.maximumNumberOfLines = 2
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(warningLabel)

        // Presets section
        let presetsLabel = NSTextField(labelWithString: "预设快捷键:")
        presetsLabel.font = NSFont.systemFont(ofSize: 12)
        presetsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(presetsLabel)

        setupPresetButtons()
        presetStackView.orientation = .vertical
        presetStackView.alignment = .leading
        presetStackView.spacing = 8
        presetStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(presetStackView)

        // Restore default button
        restoreDefaultButton.target = self
        restoreDefaultButton.action = #selector(restoreDefaultAction)
        restoreDefaultButton.bezelStyle = .rounded
        restoreDefaultButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(restoreDefaultButton)

        // Bottom buttons
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}" // Escape
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)

        saveButton.target = self
        saveButton.action = #selector(saveAction)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r" // Return
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            hotkeyDisplayField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            hotkeyDisplayField.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            hotkeyDisplayField.widthAnchor.constraint(equalToConstant: 250),
            hotkeyDisplayField.heightAnchor.constraint(equalToConstant: 40),

            captureButton.topAnchor.constraint(equalTo: hotkeyDisplayField.bottomAnchor, constant: 12),
            captureButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            warningLabel.topAnchor.constraint(equalTo: captureButton.bottomAnchor, constant: 8),
            warningLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            warningLabel.widthAnchor.constraint(equalToConstant: 320),

            presetsLabel.topAnchor.constraint(equalTo: warningLabel.bottomAnchor, constant: 16),
            presetsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            presetStackView.topAnchor.constraint(equalTo: presetsLabel.bottomAnchor, constant: 8),
            presetStackView.leadingAnchor.constraint(equalTo: presetsLabel.leadingAnchor),

            restoreDefaultButton.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -20),
            restoreDefaultButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),

            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),

            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    private func setupPresetButtons() {
        let presets: [(title: String, config: HotkeyConfig)] = [
            ("Ctrl 双击 (默认)", HotkeyConfig.default),
            ("Cmd + Space", HotkeyConfig(triggerType: .combination, keyCode: 49, modifiers: .command, interval: 0.3)),
            ("Option + Space", HotkeyConfig(triggerType: .combination, keyCode: 49, modifiers: .option, interval: 0.3))
        ]

        for (index, preset) in presets.enumerated() {
            let button = NSButton(title: preset.title, target: self, action: #selector(selectPreset(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            presetConfigs[index] = preset.config
            presetStackView.addArrangedSubview(button)
        }
    }

    private func updateHotkeyDisplay() {
        hotkeyDisplayField.stringValue = currentConfig.displayString
        validateHotkeyConfig()
    }

    private func validateHotkeyConfig() {
        let conflict = detectSystemShortcutConflict(config: currentConfig)

        if let conflictDescription = conflict {
            warningLabel.stringValue = "⚠️ \(conflictDescription)"
            warningLabel.isHidden = false
        } else {
            warningLabel.stringValue = ""
            warningLabel.isHidden = true
        }
    }

    private func detectSystemShortcutConflict(config: HotkeyConfig) -> String? {
        guard config.triggerType == .combination else {
            return nil
        }

        let modifiers = config.modifiers
        let keyCode = config.keyCode

        // Cmd+Q (Quit)
        if modifiers.contains(.command) && !modifiers.contains(.shift) &&
           !modifiers.contains(.option) && !modifiers.contains(.control) && keyCode == 12 {
            return "此快捷键与系统\"退出应用\"冲突"
        }

        // Cmd+Tab (Application Switcher)
        if modifiers.contains(.command) && !modifiers.contains(.shift) &&
           !modifiers.contains(.option) && !modifiers.contains(.control) && keyCode == 48 {
            return "此快捷键与系统\"应用切换器\"冲突"
        }

        // Cmd+Space (Spotlight)
        if modifiers.contains(.command) && !modifiers.contains(.shift) &&
           !modifiers.contains(.option) && !modifiers.contains(.control) && keyCode == 49 {
            return "此快捷键可能与Spotlight冲突"
        }

        // Cmd+W (Close Window)
        if modifiers.contains(.command) && !modifiers.contains(.shift) &&
           !modifiers.contains(.option) && !modifiers.contains(.control) && keyCode == 13 {
            return "此快捷键与系统\"关闭窗口\"冲突"
        }

        // Cmd+M (Minimize)
        if modifiers.contains(.command) && !modifiers.contains(.shift) &&
           !modifiers.contains(.option) && !modifiers.contains(.control) && keyCode == 46 {
            return "此快捷键与系统\"最小化窗口\"冲突"
        }

        // Cmd+H (Hide)
        if modifiers.contains(.command) && !modifiers.contains(.shift) &&
           !modifiers.contains(.option) && !modifiers.contains(.control) && keyCode == 4 {
            return "此快捷键与系统\"隐藏应用\"冲突"
        }

        // Cmd+Option+Esc (Force Quit)
        if modifiers.contains(.command) && modifiers.contains(.option) &&
           !modifiers.contains(.shift) && !modifiers.contains(.control) && keyCode == 53 {
            return "此快捷键与系统\"强制退出\"冲突"
        }

        return nil
    }

    @objc private func startCapture() {
        if isCapturing {
            stopCapture()
            return
        }

        isCapturing = true
        captureButton.title = "按下快捷键... (ESC 取消)"
        hotkeyDisplayField.stringValue = "等待输入..."

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            // Cancel on Escape
            if event.keyCode == 53 {
                self.stopCapture()
                return nil
            }

            // Capture key combination
            if event.type == .keyDown {
                let keyCode = event.keyCode
                let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

                // Determine trigger type
                let triggerType: HotkeyConfig.TriggerType
                if modifiers.isEmpty {
                    // Single key double-tap
                    triggerType = .doubleTap
                } else {
                    // Combination key
                    triggerType = .combination
                }

                self.currentConfig = HotkeyConfig(
                    triggerType: triggerType,
                    keyCode: keyCode,
                    modifiers: modifiers,
                    interval: 0.3
                )

                self.stopCapture()
                self.updateHotkeyDisplay()
                return nil
            }

            return event
        }
    }

    private func stopCapture() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isCapturing = false
        captureButton.title = "录制快捷键..."
    }

    @objc private func selectPreset(_ sender: NSButton) {
        guard let config = presetConfigs[sender.tag] else { return }
        currentConfig = config
        updateHotkeyDisplay()
    }

    @objc private func restoreDefaultAction() {
        currentConfig = HotkeyConfig.default
        updateHotkeyDisplay()
        onReset?()
    }

    @objc private func cancelAction() {
        stopCapture()
        close()
        onCancel?()
    }

    @objc private func saveAction() {
        stopCapture()
        onSave?(currentConfig)
        close()
    }

    deinit {
        stopCapture()
    }
}

// MARK: - HotkeyConfig

struct HotkeyConfig: Codable {
    enum TriggerType: String, Codable {
        case doubleTap
        case combination
    }

    let triggerType: TriggerType
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    let interval: TimeInterval

    static let `default` = HotkeyConfig(
        triggerType: .doubleTap,
        keyCode: 59, // Left Control
        modifiers: [],
        interval: 0.3
    )

    var displayString: String {
        switch triggerType {
        case .doubleTap:
            return "\(keyName(for: keyCode)) 双击"
        case .combination:
            var parts: [String] = []
            if modifiers.contains(.command) { parts.append("⌘") }
            if modifiers.contains(.option) { parts.append("⌥") }
            if modifiers.contains(.control) { parts.append("⌃") }
            if modifiers.contains(.shift) { parts.append("⇧") }
            parts.append(keyName(for: keyCode))
            return parts.joined(separator: " + ")
        }
    }

    private func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 49: return "Space"
        case 53: return "Esc"
        case 59: return "Left Ctrl"
        case 62: return "Right Ctrl"
        case 55: return "Cmd"
        case 58: return "Option"
        case 56: return "Shift"
        default: return "Key \(keyCode)"
        }
    }

    // Custom Codable implementation to handle NSEvent.ModifierFlags
    enum CodingKeys: String, CodingKey {
        case triggerType, keyCode, modifiers, interval
    }

    init(triggerType: TriggerType, keyCode: UInt16, modifiers: NSEvent.ModifierFlags, interval: TimeInterval) {
        self.triggerType = triggerType
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.interval = interval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        triggerType = try container.decode(TriggerType.self, forKey: .triggerType)
        keyCode = try container.decode(UInt16.self, forKey: .keyCode)
        let rawModifiers = try container.decode(UInt.self, forKey: .modifiers)
        modifiers = NSEvent.ModifierFlags(rawValue: rawModifiers)
        interval = try container.decode(TimeInterval.self, forKey: .interval)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(triggerType, forKey: .triggerType)
        try container.encode(keyCode, forKey: .keyCode)
        try container.encode(modifiers.rawValue, forKey: .modifiers)
        try container.encode(interval, forKey: .interval)
    }
}
