import AppKit
import SwiftUI

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
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 500

        let frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        let win = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.title = localized("permission_title")
        win.isReleasedWhenClosed = false
        win.level = .floating
        win.center()

        window = win
    }

    // MARK: - Content Update

    private func updateContent() {
        guard let window else { return }

        let permissionStatus = PermissionManager.shared.checkAllPermissions()

        let contentView = PermissionAlertContentView(
            permissionStatus: permissionStatus,
            onOpenAccessibilitySettings: { [weak self] in
                self?.openAccessibilitySettings()
            },
            onOpenMicrophoneSettings: { [weak self] in
                self?.openMicrophoneSettings()
            },
            onRetry: { [weak self] in
                self?.retryCheckAction()
            },
            onRestart: { [weak self] in
                self?.restartAppAction()
            }
        )

        window.contentView = NSHostingView(rootView: contentView)
    }

    // MARK: - Actions

    private func openAccessibilitySettings() {
        NSLog("[PermissionAlertWindow] Opening Accessibility Settings")
        PermissionManager.shared.openSystemSettings(for: .accessibility)
    }

    private func openMicrophoneSettings() {
        NSLog("[PermissionAlertWindow] Opening Microphone Settings")
        PermissionManager.shared.openSystemSettings(for: .microphone)
    }

    private func retryCheckAction() {
        NSLog("[PermissionAlertWindow] Retry check requested")
        updateContent()
        onRetryCheck?()
    }

    private func restartAppAction() {
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
                "en": "How to fix permissions:",
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
            ],
            "permission_required_title": [
                "ko": "권한이 필요합니다",
                "en": "Permissions Required",
                "zh": "需要以下权限"
            ],
            "permission_required_desc": [
                "ko": "VoiceFlow가 정상적으로 작동하려면 다음 권한이 필요합니다:",
                "en": "VoiceFlow needs the following permissions to work properly:",
                "zh": "VoiceFlow 需要以下权限才能正常工作："
            ]
        ]

        return strings[key]?[language] ?? strings[key]?["zh"] ?? key
    }
}

// MARK: - SwiftUI Content View with Glassmorphism

private struct PermissionAlertContentView: View {
    let permissionStatus: PermissionManager.AllPermissionsStatus
    let onOpenAccessibilitySettings: () -> Void
    let onOpenMicrophoneSettings: () -> Void
    let onRetry: () -> Void
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            GradientBackground()

            VStack(spacing: 24) {
                // Header with icon
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 48))
                        .foregroundColor(DesignToken.Colors.warning)

                    Text(localized("permission_required_title"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(DesignToken.Colors.textPrimary)

                    Text(localized("permission_required_desc"))
                        .font(DesignToken.Typography.body)
                        .foregroundColor(DesignToken.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)

                Spacer()

                // Permission cards
                VStack(spacing: 16) {
                    PermissionCard(
                        icon: "keyboard.fill",
                        title: localized("accessibility_permission"),
                        status: permissionStatus.accessibilityState,
                        isGranted: permissionStatus.isAccessibilityGranted,
                        instructions: getAccessibilityInstructions(),
                        onOpenSettings: onOpenAccessibilitySettings
                    )

                    PermissionCard(
                        icon: "mic.fill",
                        title: localized("microphone_permission"),
                        status: permissionStatus.microphoneState,
                        isGranted: permissionStatus.isMicrophoneGranted,
                        instructions: getMicrophoneInstructions(),
                        onOpenSettings: onOpenMicrophoneSettings
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if permissionStatus.isAccessibilityGranted && permissionStatus.isMicrophoneGranted {
                        Button(action: onRetry) {
                            Text(localized("retry"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(DesignToken.Colors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(DesignToken.CornerRadius.small)
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack(spacing: 12) {
                            Button(action: onOpenAccessibilitySettings) {
                                Text(localized("open_accessibility_settings"))
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        permissionStatus.isAccessibilityGranted ?
                                        LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(colors: [DesignToken.Colors.primary, DesignToken.Colors.primary.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundColor(permissionStatus.isAccessibilityGranted ? DesignToken.Colors.textSecondary : .white)
                                    .cornerRadius(DesignToken.CornerRadius.small)
                            }
                            .buttonStyle(.plain)
                            .disabled(permissionStatus.isAccessibilityGranted)

                            Button(action: onOpenMicrophoneSettings) {
                                Text(localized("open_microphone_settings"))
                                    .font(.system(size: 13))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        permissionStatus.isMicrophoneGranted ?
                                        LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing) :
                                        LinearGradient(colors: [DesignToken.Colors.primary, DesignToken.Colors.primary.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                    )
                                    .foregroundColor(permissionStatus.isMicrophoneGranted ? DesignToken.Colors.textSecondary : .white)
                                    .cornerRadius(DesignToken.CornerRadius.small)
                            }
                            .buttonStyle(.plain)
                            .disabled(permissionStatus.isMicrophoneGranted)
                        }
                    }

                    HStack(spacing: 12) {
                        Button(action: onRetry) {
                            Text(localized("retry"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(DesignToken.Colors.textSecondary)
                                .cornerRadius(DesignToken.CornerRadius.small)
                        }
                        .buttonStyle(.plain)

                        Button(action: onRestart) {
                            Text(localized("restart"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    LinearGradient(
                                        colors: [DesignToken.Colors.warning, DesignToken.Colors.warning.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(DesignToken.CornerRadius.small)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func localized(_ key: String) -> String {
        let language = SettingsManager.shared.language

        let strings: [String: [String: String]] = [
            "permission_required_title": [
                "ko": "권한이 필요합니다",
                "en": "Permissions Required",
                "zh": "需要以下权限"
            ],
            "permission_required_desc": [
                "ko": "VoiceFlow가 정상적으로 작동하려면 다음 권한이 필요합니다:",
                "en": "VoiceFlow needs the following permissions to work properly:",
                "zh": "VoiceFlow 需要以下权限才能正常工作："
            ]
        ]

        return strings[key]?[language] ?? strings[key]?["zh"] ?? key
    }

    private func getAccessibilityInstructions() -> [String] {
        let language = SettingsManager.shared.language
        let key = "instruction_accessibility"

        let instructions: [String: [String: String]] = [
            "instruction_accessibility": [
                "ko": "VoiceFlow가 화면을 감시하고 텍스트를 입력할 수 있게 합니다",
                "en": "Allows VoiceFlow to monitor screen and inject text",
                "zh": "允许 VoiceFlow 监控屏幕并输入文字"
            ]
        ]

        return [instructions[key]?[language] ?? instructions[key]?["zh"] ?? ""]
    }

    private func getMicrophoneInstructions() -> [String] {
        let language = SettingsManager.shared.language
        let key = "instruction_microphone"

        let instructions: [String: [String: String]] = [
            "instruction_microphone": [
                "ko": "음성을 녹음하여 텍스트로 변환합니다",
                "en": "Enables voice recording for transcription",
                "zh": "启用语音录制以进行转录"
            ]
        ]

        return [instructions[key]?[language] ?? instructions[key]?["zh"] ?? ""]
    }
}

// MARK: - Permission Card Component

private struct PermissionCard: View {
    let icon: String
    let title: String
    let status: PermissionManager.PermissionStatus
    let isGranted: Bool
    let instructions: [String]
    let onOpenSettings: () -> Void

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                // Icon with status color
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)
                }

                // Title and instructions
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(DesignToken.Colors.textPrimary)

                    if let instruction = instructions.first {
                        Text(instruction)
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)
                    }
                }

                Spacer()

                // Status indicator
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 20))
                        .foregroundColor(statusColor)

                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundColor(statusColor)
                }
            }
        }
                    }

    private var statusIcon: String {
        switch status {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .notDetermined: return "questionmark.circle.fill"
        case .restricted: return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch status {
        case .granted: return DesignToken.Colors.accent
        case .denied: return DesignToken.Colors.error
        case .notDetermined: return DesignToken.Colors.warning
        case .restricted: return DesignToken.Colors.warning
        }
    }

    private var statusText: String {
        let language = SettingsManager.shared.language

        let statusTexts: [PermissionManager.PermissionStatus: [String: String]] = [
            .granted: ["ko": "已授权", "en": "Granted", "zh": "已授权"],
            .denied: ["ko": "已拒绝", "en": "Denied", "zh": "已拒绝"],
            .notDetermined: ["ko": "未确定", "en": "Not Set", "zh": "未确定"],
            .restricted: ["ko": "系统限制", "en": "Restricted", "zh": "系统限制"]
        ]

        return statusTexts[status]?[language] ?? statusTexts[status]?["zh"] ?? ""
    }
}
