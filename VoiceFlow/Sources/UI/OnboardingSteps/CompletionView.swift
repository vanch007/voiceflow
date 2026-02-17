import SwiftUI

/// Completion screen (Step 5) - Static final confirmation
struct CompletionView: View {
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // Static gradient background
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                // Static success icon
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80, weight: .medium))
                    .foregroundColor(DesignToken.Colors.accent)

                // Title
                Text("设置完成！")
                    .font(DesignToken.Typography.title)
                    .foregroundColor(DesignToken.Colors.textPrimary)

                // Success message
                Text("VoiceFlow 已准备就绪")
                    .font(DesignToken.Typography.subtitle)
                    .foregroundColor(DesignToken.Colors.textSecondary)

                Spacer()
                    .frame(height: 20)

                // GlassCard wrapped summary
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        CompletionRow(
                            icon: "mic.fill",
                            title: "麦克风权限",
                            description: "已配置语音录制权限"
                        )

                        CompletionRow(
                            icon: "lock.shield.fill",
                            title: "辅助功能权限",
                            description: "已配置热键监听和文本插入权限"
                        )

                        CompletionRow(
                            icon: "keyboard.fill",
                            title: "热键操作",
                            description: "已熟悉 Control 双击和 Option 长按"
                        )
                    }
                }
                .padding(.horizontal, 40)

                Spacer()

                // Ready to use message
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(DesignToken.Colors.warning)

                        Text("提示：按住 Option 键开始录音，释放后自动转录")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()
                    .frame(height: 10)

                // Start using button
                Button(action: onComplete) {
                    Text("开始使用")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(DesignToken.Colors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(DesignToken.CornerRadius.small)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
            }
        }
        .padding(DesignToken.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Completion Row Component
private struct CompletionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DesignToken.Colors.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignToken.Colors.textPrimary)

                Text(description)
                    .font(DesignToken.Typography.caption)
                    .foregroundColor(DesignToken.Colors.textSecondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    CompletionView(onComplete: {})
        .frame(width: 680, height: 540)
}
