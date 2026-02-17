import SwiftUI

// MARK: - Welcome Screen (Static, no animation)
struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        ZStack {
            // Static gradient background
            GradientBackground()

            VStack(spacing: 24) {
                Spacer()

                // App icon (static)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DesignToken.Colors.primary)

                // Welcome title
                Text("欢迎使用 VoiceFlow")
                    .font(DesignToken.Typography.title)
                    .foregroundColor(DesignToken.Colors.textPrimary)

                // App purpose description
                Text("语音转文字助手")
                    .font(DesignToken.Typography.subtitle)
                    .foregroundColor(DesignToken.Colors.textSecondary)

                Spacer()
                    .frame(height: 20)

                // Feature list with glass card
                GlassCard {
                    VStack(alignment: .leading, spacing: 16) {
                        FeatureRow(
                            icon: "mic.fill",
                            title: "实时语音识别",
                            description: "通过热键快速启动语音录制"
                        )

                        FeatureRow(
                            icon: "text.cursor",
                            title: "自动文本插入",
                            description: "识别结果自动插入到当前应用"
                        )

                        FeatureRow(
                            icon: "keyboard",
                            title: "便捷热键操作",
                            description: "支持 Option 长按或 Control 双击"
                        )
                    }
                }

                Spacer()

                // Setup introduction text
                Text("让我们花一分钟完成初始设置")
                    .font(DesignToken.Typography.body)
                    .foregroundColor(DesignToken.Colors.textSecondary)

                // Next button
                Button(action: onNext) {
                    Text("开始设置")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(DesignToken.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(DesignToken.CornerRadius.medium)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 40)
            }
            .padding(DesignToken.Spacing.xl)
        }
    }
}

// MARK: - Feature Row Component
private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DesignToken.Colors.primary)
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
    WelcomeView(onNext: {})
        .frame(width: 680, height: 540)
}
