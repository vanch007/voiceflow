import SwiftUI

/// Completion screen (Step 5) - Final confirmation that onboarding is complete
struct CompletionView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            // Title
            Text("设置完成！")
                .font(.system(size: 28, weight: .bold))

            // Success message
            Text("VoiceFlow 已准备就绪")
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Spacer()
                .frame(height: 20)

            // Summary of what was configured
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
            .padding(.horizontal, 40)

            Spacer()

            // Ready to use message
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)

                    Text("提示：按住 Option 键开始录音，释放后自动转录")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
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
                    .background(Color.green)
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

// MARK: - Completion Row Component
private struct CompletionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.green)
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
    CompletionView(onComplete: {})
        .frame(width: 600, height: 500)
}
