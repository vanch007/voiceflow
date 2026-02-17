import SwiftUI
import AppKit

/// Accessibility Permission screen (Static, no animation)
struct AccessibilityPermissionView: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var isPermissionGranted = false
    @State private var isChecking = false
    private let poller = PermissionPoller()

    var body: some View {
        ZStack {
            // Static gradient background
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                // Static accessibility icon
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 80))
                    .foregroundColor(isPermissionGranted ? DesignToken.Colors.accent : DesignToken.Colors.primary)

                // Title
                Text("辅助功能权限")
                    .font(DesignToken.Typography.title)
                    .foregroundColor(DesignToken.Colors.textPrimary)

                // Description
                Text("需要辅助功能权限来监听热键和插入转录文本")
                    .font(DesignToken.Typography.subtitle)
                    .foregroundColor(DesignToken.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 20)

                // GlassCard for permission status indicator
                GlassCard {
                    HStack(spacing: 12) {
                        Image(systemName: statusIcon)
                            .font(.system(size: 20))
                            .foregroundColor(statusColor)

                        Text(statusText)
                            .font(DesignToken.Typography.body)
                            .foregroundColor(DesignToken.Colors.textPrimary)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // GlassCard for explanation text
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("为什么需要此权限？")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignToken.Colors.textPrimary)

                        Text("• 监听全局热键（Option 长按 / Control 双击）")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)

                        Text("• 将转录文本自动插入到当前应用")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)

                        Text("• 控制录音状态和界面显示")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 40)

                // Warning for denied permission
                if !isPermissionGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(DesignToken.Colors.warning)

                        Text("此权限是必需的，应用无法正常工作")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.warning)
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if !isPermissionGranted {
                        Button(action: requestPermission) {
                            Text("打开系统设置")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(DesignToken.Colors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(DesignToken.CornerRadius.small)
                        }
                        .buttonStyle(.plain)

                        // 提示用户授权后会自动前进
                        Text("授权后将自动继续")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)
                    } else {
                        Button(action: onNext) {
                            Text("继续")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(DesignToken.Colors.accent)
                                .foregroundColor(.white)
                                .cornerRadius(DesignToken.CornerRadius.small)
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onBack) {
                        Text("返回")
                            .font(DesignToken.Typography.body)
                            .foregroundColor(DesignToken.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding(DesignToken.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkPermissionStatus()
            // 启动轮询：用户在系统设置中授权后自动前进
            poller.startPolling(for: .accessibility) {
                isPermissionGranted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onNext()
                }
            }
        }
        .onDisappear {
            poller.stopPolling()
        }
    }

    // MARK: - Permission Helpers

    private func checkPermissionStatus() {
        isChecking = true

        // Check accessibility permission without prompting
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        let granted = AXIsProcessTrustedWithOptions(options)

        DispatchQueue.main.async {
            isChecking = false
            isPermissionGranted = granted

            // If permission granted, auto-proceed after brief delay
            if granted {
                poller.stopPolling()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onNext()
                }
            }
        }
    }

    private func requestPermission() {
        // Request accessibility permission with system prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)

        // Open System Settings to Privacy & Security -> Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Status Computed Properties

    private var statusIcon: String {
        isPermissionGranted ? "checkmark.circle.fill" : "xmark.circle.fill"
    }

    private var statusColor: Color {
        isPermissionGranted ? DesignToken.Colors.accent : DesignToken.Colors.warning
    }

    private var statusText: String {
        isPermissionGranted ? "已授权" : "未授权 - 需要在系统设置中启用"
    }
}

// MARK: - Preview
#Preview {
    AccessibilityPermissionView(onNext: {}, onBack: {})
        .frame(width: 600, height: 500)
}
