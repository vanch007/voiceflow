import AppKit

final class HotkeySettingsWindow: NSWindow {
    var onSave: ((HotkeyConfig, HotkeyConfig) -> Void)?  // (voiceInput, systemAudio)
    var onCancel: (() -> Void)?

    private var selectedVoiceConfig: HotkeyConfig
    private var selectedSystemAudioConfig: HotkeyConfig
    private var voicePresetButtons: [NSButton] = []
    private var systemAudioPresetButtons: [NSButton] = []
    private let warningLabel: NSTextField
    private let cancelButton: NSButton
    private let saveButton: NSButton

    init() {
        // Load current configs
        if let savedData = UserDefaults.standard.data(forKey: "voiceflow.hotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) {
            selectedVoiceConfig = config
        } else {
            selectedVoiceConfig = HotkeyConfig.default
        }

        if let savedData = UserDefaults.standard.data(forKey: "voiceflow.systemAudioHotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: savedData) {
            selectedSystemAudioConfig = config
        } else {
            selectedSystemAudioConfig = HotkeyConfig.systemAudioDefault
        }

        warningLabel = NSTextField(labelWithString: "")
        cancelButton = NSButton(title: "取消", target: nil, action: nil)
        saveButton = NSButton(title: "保存", target: nil, action: nil)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "快捷键设置"
        self.isReleasedWhenClosed = false
        self.center()

        setupUI()
        updateSelection()
    }

    private func setupUI() {
        let contentView = NSView(frame: self.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        self.contentView = contentView

        // === 语音输入模式 ===
        let voiceTitle = NSTextField(labelWithString: "语音输入模式")
        voiceTitle.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        voiceTitle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(voiceTitle)

        let voiceDesc = NSTextField(labelWithString: "按住说话，松开结束")
        voiceDesc.font = NSFont.systemFont(ofSize: 11)
        voiceDesc.textColor = .secondaryLabelColor
        voiceDesc.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(voiceDesc)

        let voiceStackView = NSStackView()
        voiceStackView.orientation = .horizontal
        voiceStackView.spacing = 8
        voiceStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(voiceStackView)

        for (index, preset) in HotkeyConfig.voiceInputPresets.enumerated() {
            let button = NSButton(title: preset.title, target: self, action: #selector(selectVoicePreset(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            button.setButtonType(.onOff)
            voicePresetButtons.append(button)
            voiceStackView.addArrangedSubview(button)
        }

        // === 系统音频录制模式 ===
        let systemTitle = NSTextField(labelWithString: "系统音频录制模式")
        systemTitle.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        systemTitle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(systemTitle)

        let systemDesc = NSTextField(labelWithString: "录制电脑播放的声音并生成字幕")
        systemDesc.font = NSFont.systemFont(ofSize: 11)
        systemDesc.textColor = .secondaryLabelColor
        systemDesc.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(systemDesc)

        let systemStackView = NSStackView()
        systemStackView.orientation = .horizontal
        systemStackView.spacing = 8
        systemStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(systemStackView)

        for (index, preset) in HotkeyConfig.systemAudioPresets.enumerated() {
            let button = NSButton(title: preset.title, target: self, action: #selector(selectSystemAudioPreset(_:)))
            button.bezelStyle = .rounded
            button.tag = index
            button.setButtonType(.onOff)
            systemAudioPresetButtons.append(button)
            systemStackView.addArrangedSubview(button)
        }

        // === 分隔线 ===
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(separator)

        // === 冲突警告 ===
        warningLabel.isEditable = false
        warningLabel.isBordered = false
        warningLabel.drawsBackground = false
        warningLabel.textColor = .systemOrange
        warningLabel.font = NSFont.systemFont(ofSize: 11)
        warningLabel.alignment = .center
        warningLabel.lineBreakMode = .byWordWrapping
        warningLabel.maximumNumberOfLines = 2
        warningLabel.isHidden = true
        warningLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(warningLabel)

        // === 底部按钮 ===
        cancelButton.target = self
        cancelButton.action = #selector(cancelAction)
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cancelButton)

        saveButton.target = self
        saveButton.action = #selector(saveAction)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)

        // Layout
        NSLayoutConstraint.activate([
            // 语音输入标题
            voiceTitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            voiceTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            voiceDesc.topAnchor.constraint(equalTo: voiceTitle.bottomAnchor, constant: 4),
            voiceDesc.leadingAnchor.constraint(equalTo: voiceTitle.leadingAnchor),

            // 语音输入预设按钮
            voiceStackView.topAnchor.constraint(equalTo: voiceDesc.bottomAnchor, constant: 12),
            voiceStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            voiceStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            // 分隔线
            separator.topAnchor.constraint(equalTo: voiceStackView.bottomAnchor, constant: 20),
            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            // 系统音频标题
            systemTitle.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 20),
            systemTitle.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            systemDesc.topAnchor.constraint(equalTo: systemTitle.bottomAnchor, constant: 4),
            systemDesc.leadingAnchor.constraint(equalTo: systemTitle.leadingAnchor),

            // 系统音频预设按钮
            systemStackView.topAnchor.constraint(equalTo: systemDesc.bottomAnchor, constant: 12),
            systemStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            systemStackView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),

            // 冲突警告
            warningLabel.topAnchor.constraint(equalTo: systemStackView.bottomAnchor, constant: 16),
            warningLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            warningLabel.widthAnchor.constraint(equalToConstant: 360),

            // 底部按钮
            cancelButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),

            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
        ])
    }

    private func updateSelection() {
        // 更新语音输入按钮高亮
        for (index, button) in voicePresetButtons.enumerated() {
            let preset = HotkeyConfig.voiceInputPresets[index]
            if preset.config == selectedVoiceConfig {
                button.state = .on
                button.contentTintColor = .controlAccentColor
                button.isBordered = true
                (button.cell as? NSButtonCell)?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15)
            } else {
                button.state = .off
                button.contentTintColor = nil
                (button.cell as? NSButtonCell)?.backgroundColor = nil
            }
        }

        // 更新系统音频按钮高亮
        for (index, button) in systemAudioPresetButtons.enumerated() {
            let preset = HotkeyConfig.systemAudioPresets[index]
            if preset.config == selectedSystemAudioConfig {
                button.state = .on
                button.contentTintColor = .controlAccentColor
                (button.cell as? NSButtonCell)?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15)
            } else {
                button.state = .off
                button.contentTintColor = nil
                (button.cell as? NSButtonCell)?.backgroundColor = nil
            }
        }

        // 检查冲突
        checkConflict()
    }

    private func checkConflict() {
        if selectedVoiceConfig == selectedSystemAudioConfig {
            warningLabel.stringValue = "⚠️ 语音输入和系统音频使用了相同的快捷键，请选择不同的方案"
            warningLabel.isHidden = false
            saveButton.isEnabled = false
        } else {
            warningLabel.isHidden = true
            saveButton.isEnabled = true
        }
    }

    @objc private func selectVoicePreset(_ sender: NSButton) {
        let index = sender.tag
        guard index < HotkeyConfig.voiceInputPresets.count else { return }
        selectedVoiceConfig = HotkeyConfig.voiceInputPresets[index].config
        updateSelection()
    }

    @objc private func selectSystemAudioPreset(_ sender: NSButton) {
        let index = sender.tag
        guard index < HotkeyConfig.systemAudioPresets.count else { return }
        selectedSystemAudioConfig = HotkeyConfig.systemAudioPresets[index].config
        updateSelection()
    }

    @objc private func cancelAction() {
        close()
        onCancel?()
    }

    @objc private func saveAction() {
        // Save voice input config
        if let encoded = try? JSONEncoder().encode(selectedVoiceConfig) {
            UserDefaults.standard.set(encoded, forKey: "voiceflow.hotkeyConfig")
        }
        NotificationCenter.default.post(
            name: .hotkeyConfigDidChange,
            object: nil,
            userInfo: ["config": selectedVoiceConfig]
        )

        // Save system audio config
        if let encoded = try? JSONEncoder().encode(selectedSystemAudioConfig) {
            UserDefaults.standard.set(encoded, forKey: "voiceflow.systemAudioHotkeyConfig")
        }
        NotificationCenter.default.post(
            name: .systemAudioHotkeyConfigDidChange,
            object: nil,
            userInfo: ["config": selectedSystemAudioConfig]
        )

        onSave?(selectedVoiceConfig, selectedSystemAudioConfig)
        close()
    }
}
