import AppKit

final class PermissionAlertWindow: NSObject {
    private var window: NSWindow?
    var onRetryCheck: (() -> Void)?

    private var accessibilityPoller: PermissionPoller?
    private var microphonePoller: PermissionPoller?

    // MARK: - Public Methods

    func show() {
        if window == nil {
            createWindow()
        }
        updateContent()
        window?.makeKeyAndOrderFront(nil)
        window?.center()

        // 启动轮询，自动检测权限变化
        let status = PermissionManager.shared.checkAllPermissions()
        if !status.isAccessibilityGranted {
            accessibilityPoller = PermissionPoller()
            accessibilityPoller?.startPolling(for: .accessibility) { [weak self] in
                self?.checkAndAutoClose()
            }
        }
        if !status.isMicrophoneGranted {
            microphonePoller = PermissionPoller()
            microphonePoller?.startPolling(for: .microphone) { [weak self] in
                self?.checkAndAutoClose()
            }
        }
    }

    func hide() {
        accessibilityPoller?.stopPolling()
        accessibilityPoller = nil
        microphonePoller?.stopPolling()
        microphonePoller = nil
        window?.close()
        window = nil
    }

    private func checkAndAutoClose() {
        let status = PermissionManager.shared.checkAllPermissions()
        if status.isAccessibilityGranted && status.isMicrophoneGranted {
            NSLog("[PermissionAlertWindow] All permissions granted, auto-closing")
            DispatchQueue.main.async {
                self.onRetryCheck?()
                self.hide()
            }
        } else {
            DispatchQueue.main.async {
                self.updateContent()
            }
        }
    }

    // MARK: - Window Creation

    private func createWindow() {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 400

        let frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = localized("permission_title")
        win.isReleasedWhenClosed = false
        win.level = .floating

        window = win
    }

    // MARK: - Content Update

    private func updateContent() {
        guard let window else { return }

        let permissionStatus = PermissionManager.shared.checkAllPermissions()

        let contentView = NSView(frame: window.contentView?.bounds ?? .zero)
        contentView.wantsLayer = true

        var yPosition: CGFloat = window.frame.height - 60

        // Title
        let titleLabel = NSTextField(labelWithString: localized("permission_title"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPosition, width: window.frame.width - 40, height: 24)
        contentView.addSubview(titleLabel)
        yPosition -= 40

        // Accessibility Status
        let accessibilityStack = createPermissionStatusView(
            title: localized("accessibility_permission"),
            status: permissionStatus.accessibilityState,
            isGranted: permissionStatus.isAccessibilityGranted
        )
        accessibilityStack.frame = NSRect(x: 20, y: yPosition, width: window.frame.width - 40, height: 24)
        contentView.addSubview(accessibilityStack)
        yPosition -= 30

        // Microphone Status
        let microphoneStack = createPermissionStatusView(
            title: localized("microphone_permission"),
            status: permissionStatus.microphoneState,
            isGranted: permissionStatus.isMicrophoneGranted
        )
        microphoneStack.frame = NSRect(x: 20, y: yPosition, width: window.frame.width - 40, height: 24)
        contentView.addSubview(microphoneStack)
        yPosition -= 40

        // Instructions Section
        if !permissionStatus.isAccessibilityGranted || !permissionStatus.isMicrophoneGranted {
            let instructionsLabel = NSTextField(labelWithString: localized("instructions_title"))
            instructionsLabel.font = NSFont.boldSystemFont(ofSize: 13)
            instructionsLabel.frame = NSRect(x: 20, y: yPosition, width: window.frame.width - 40, height: 20)
            contentView.addSubview(instructionsLabel)
            yPosition -= 30

            // Instructions text
            let instructions = getInstructions(
                accessibilityGranted: permissionStatus.isAccessibilityGranted,
                microphoneGranted: permissionStatus.isMicrophoneGranted
            )

            for (index, instruction) in instructions.enumerated() {
                let instructionLabel = NSTextField(labelWithString: "\(index + 1). \(instruction)")
                instructionLabel.font = NSFont.systemFont(ofSize: 12)
                instructionLabel.lineBreakMode = .byWordWrapping
                instructionLabel.maximumNumberOfLines = 0
                instructionLabel.frame = NSRect(x: 30, y: yPosition, width: window.frame.width - 60, height: 40)
                contentView.addSubview(instructionLabel)
                yPosition -= 45
            }

            yPosition -= 10
        }

        // Action Buttons
        let buttonY: CGFloat = 20
        var buttonX: CGFloat = window.frame.width - 120

        // Restart Button
        let restartButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: 100, height: 32))
        restartButton.title = localized("restart")
        restartButton.bezelStyle = .rounded
        restartButton.target = self
        restartButton.action = #selector(restartAppAction)
        contentView.addSubview(restartButton)
        buttonX -= 110

        // Retry Button
        let retryButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: 100, height: 32))
        retryButton.title = localized("retry")
        retryButton.bezelStyle = .rounded
        retryButton.target = self
        retryButton.action = #selector(retryCheckAction)
        contentView.addSubview(retryButton)
        buttonX -= 200

        // Open Accessibility Settings Button (if needed)
        if !permissionStatus.isAccessibilityGranted {
            let accessibilityButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: 180, height: 32))
            accessibilityButton.title = localized("open_accessibility_settings")
            accessibilityButton.bezelStyle = .rounded
            accessibilityButton.target = self
            accessibilityButton.action = #selector(openAccessibilitySettings)
            contentView.addSubview(accessibilityButton)
            buttonX -= 190
        }

        // Open Microphone Settings Button (if needed)
        if !permissionStatus.isMicrophoneGranted {
            let microphoneButton = NSButton(frame: NSRect(x: buttonX, y: buttonY, width: 180, height: 32))
            microphoneButton.title = localized("open_microphone_settings")
            microphoneButton.bezelStyle = .rounded
            microphoneButton.target = self
            microphoneButton.action = #selector(openMicrophoneSettings)
            contentView.addSubview(microphoneButton)
        }

        window.contentView = contentView
    }

    // MARK: - Helper Methods

    private func createPermissionStatusView(title: String, status: PermissionManager.PermissionStatus, isGranted: Bool) -> NSView {
        let view = NSView(frame: .zero)

        // Icon
        let iconImageName: String
        let iconColor: NSColor

        switch status {
        case .granted:
            iconImageName = "checkmark.circle.fill"
            iconColor = .systemGreen
        case .denied:
            iconImageName = "xmark.circle.fill"
            iconColor = .systemRed
        case .notDetermined:
            iconImageName = "questionmark.circle.fill"
            iconColor = .systemOrange
        case .restricted:
            iconImageName = "exclamationmark.triangle.fill"
            iconColor = .systemYellow
        }

        let iconImage = NSImage(systemSymbolName: iconImageName, accessibilityDescription: nil)
        let config = NSImage.SymbolConfiguration(paletteColors: [iconColor])
        let coloredIcon = iconImage?.withSymbolConfiguration(config)

        let iconView = NSImageView(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        iconView.image = coloredIcon
        view.addSubview(iconView)

        // Title
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 13)
        titleLabel.frame = NSRect(x: 28, y: 2, width: 200, height: 18)
        view.addSubview(titleLabel)

        // Status
        let statusText = localized(statusKey(for: status))
        let statusLabel = NSTextField(labelWithString: statusText)
        statusLabel.font = NSFont.systemFont(ofSize: 13)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.frame = NSRect(x: 240, y: 2, width: 200, height: 18)
        view.addSubview(statusLabel)

        return view
    }

    private func statusKey(for status: PermissionManager.PermissionStatus) -> String {
        switch status {
        case .granted:
            return "permission_granted"
        case .denied:
            return "permission_denied"
        case .notDetermined:
            return "permission_not_determined"
        case .restricted:
            return "permission_restricted"
        }
    }

    private func getInstructions(accessibilityGranted: Bool, microphoneGranted: Bool) -> [String] {
        var instructions: [String] = []

        if !accessibilityGranted {
            instructions.append(localized("instruction_click_accessibility"))
            instructions.append(localized("instruction_find_voiceflow"))
            instructions.append(localized("instruction_toggle_off_on"))
            instructions.append(localized("instruction_restart"))
        } else if !microphoneGranted {
            instructions.append(localized("instruction_click_microphone"))
            instructions.append(localized("instruction_find_voiceflow"))
            instructions.append(localized("instruction_enable"))
            instructions.append(localized("instruction_restart"))
        }

        return instructions
    }

    // MARK: - Actions

    @objc private func openAccessibilitySettings() {
        NSLog("[PermissionAlertWindow] Opening Accessibility Settings")
        PermissionManager.shared.openSystemSettings(for: .accessibility)
    }

    @objc private func openMicrophoneSettings() {
        NSLog("[PermissionAlertWindow] Opening Microphone Settings")
        PermissionManager.shared.openSystemSettings(for: .microphone)
    }

    @objc private func retryCheckAction() {
        NSLog("[PermissionAlertWindow] Retry check requested")
        updateContent()
        onRetryCheck?()
    }

    @objc private func restartAppAction() {
        NSLog("[PermissionAlertWindow] Restart app requested")
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-n", bundlePath]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }

    // MARK: - Localization

    private func localized(_ key: String) -> String {
        let language = SettingsManager.shared.language

        let strings: [String: [String: String]] = [
            "permission_title": [
                "ko": "권한 상태",
                "en": "Permission Status",
                "zh": "权限状态"
            ],
            "accessibility_permission": [
                "ko": "접근성 권한",
                "en": "Accessibility Access",
                "zh": "辅助功能权限"
            ],
            "microphone_permission": [
                "ko": "마이크 권한",
                "en": "Microphone Access",
                "zh": "麦克风权限"
            ],
            "permission_granted": [
                "ko": "승인됨",
                "en": "Granted",
                "zh": "已授权"
            ],
            "permission_denied": [
                "ko": "거부됨",
                "en": "Denied",
                "zh": "已拒绝"
            ],
            "permission_not_determined": [
                "ko": "미결정",
                "en": "Not Determined",
                "zh": "未确定"
            ],
            "permission_restricted": [
                "ko": "시스템 제한",
                "en": "Restricted by System",
                "zh": "系统限制"
            ],
            "open_accessibility_settings": [
                "ko": "접근성 설정 열기",
                "en": "Open Accessibility Settings",
                "zh": "打开辅助功能设置"
            ],
            "open_microphone_settings": [
                "ko": "마이크 설정 열기",
                "en": "Open Microphone Settings",
                "zh": "打开麦克风设置"
            ],
            "retry": [
                "ko": "재시도",
                "en": "Retry",
                "zh": "重试"
            ],
            "restart": [
                "ko": "재시작",
                "en": "Restart",
                "zh": "重启应用"
            ],
            "instructions_title": [
                "ko": "권한 수정 방법:",
                "en": "To fix permissions:",
                "zh": "修复权限的步骤："
            ],
            "instruction_click_accessibility": [
                "ko": "\"접근성 설정 열기\" 버튼 클릭",
                "en": "Click \"Open Accessibility Settings\" button",
                "zh": "点击\"打开辅助功能设置\"按钮"
            ],
            "instruction_click_microphone": [
                "ko": "\"마이크 설정 열기\" 버튼 클릭",
                "en": "Click \"Open Microphone Settings\" button",
                "zh": "点击\"打开麦克风设置\"按钮"
            ],
            "instruction_find_voiceflow": [
                "ko": "목록에서 VoiceFlow 찾기",
                "en": "Find VoiceFlow in the list",
                "zh": "在列表中找到 VoiceFlow"
            ],
            "instruction_toggle_off_on": [
                "ko": "VoiceFlow를 선택하고 - 버튼으로 삭제한 후 + 버튼으로 다시 추가 (재컴파일 후 필수)",
                "en": "Select VoiceFlow, click - to remove it, then click + to re-add (required after rebuild)",
                "zh": "选中 VoiceFlow，点击 - 按钮删除，再点击 + 按钮重新添加（重新编译后必需）"
            ],
            "instruction_enable": [
                "ko": "VoiceFlow 권한 활성화",
                "en": "Enable VoiceFlow permission",
                "zh": "启用 VoiceFlow 权限"
            ],
            "instruction_restart": [
                "ko": "VoiceFlow 재시작",
                "en": "Restart VoiceFlow",
                "zh": "重启 VoiceFlow"
            ]
        ]

        return strings[key]?[language] ?? strings[key]?["zh"] ?? key
    }
}
