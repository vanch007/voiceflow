import SwiftUI

/// Welcome screen (Step 1) - First-time onboarding wizard introduction
struct WelcomeView: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // App icon/logo area
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Welcome title
            Text("欢迎使用 VoiceFlow")
                .font(.system(size: 28, weight: .bold))

            // App purpose description
            Text("语音转文字助手")
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Spacer()
                .frame(height: 20)

            // Feature introduction
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
            .padding(.horizontal, 40)

            Spacer()

            // Setup introduction text
            Text("让我们花一分钟完成初始设置")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            // Next button
            Button(action: onNext) {
                Text("开始设置")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .foregroundColor(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    WelcomeView(onNext: {})
        .frame(width: 600, height: 500)
}
