import SwiftUI
import AppKit

/// Accessibility Permission screen (Step 3) - Request accessibility access for hotkey monitoring and text injection
struct AccessibilityPermissionView: View {
    let onNext: () -> Void

    @State private var isPermissionGranted = false
    @State private var isChecking = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Accessibility icon
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            Text("辅助功能权限")
                .font(.system(size: 28, weight: .bold))

            // Description
            Text("需要辅助功能权限来监听热键和插入转录文本")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
                .frame(height: 20)

            // Permission status indicator
            HStack(spacing: 12) {
                Image(systemName: statusIcon)
                    .font(.system(size: 20))
                    .foregroundColor(statusColor)

                Text(statusText)
                    .font(.system(size: 14))
                    .foregroundColor(.primary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 40)

            Spacer()

            // Explanation text
            VStack(alignment: .leading, spacing: 8) {
                Text("为什么需要此权限？")
                    .font(.system(size: 14, weight: .medium))

                Text("• 监听全局热键（Option 长按 / Control 双击）")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("• 将转录文本自动插入到当前应用")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("• 控制录音状态和界面显示")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            // Warning for denied permission
            if !isPermissionGranted {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    Text("此权限是必需的，应用无法正常工作")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
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
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    Button(action: checkPermissionStatus) {
                        Text(isChecking ? "检查中..." : "我已授权，继续")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isChecking)
                } else {
                    Button(action: onNext) {
                        Text("继续")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            checkPermissionStatus()
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
        isPermissionGranted ? .green : .red
    }

    private var statusText: String {
        isPermissionGranted ? "已授权" : "未授权 - 需要在系统设置中启用"
    }
}

// MARK: - Preview
#Preview {
    AccessibilityPermissionView(onNext: {})
        .frame(width: 600, height: 500)
}
