import SwiftUI
import AVFoundation

/// Microphone Permission screen (Static, no animation)
struct MicrophonePermissionView: View {
    let onNext: () -> Void
    let onBack: () -> Void

    enum MicPermission { case undetermined, granted, denied }
    @State private var permissionStatus: MicPermission = .undetermined
    @State private var isRequesting = false
    private let poller = PermissionPoller()

    var body: some View {
        ZStack {
            // Static gradient background
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                // Static microphone icon
                Image(systemName: "mic.fill")
                    .font(.system(size: 80))
                    .foregroundColor(statusColor)

                // Title
                Text("麦克风权限")
                    .font(DesignToken.Typography.title)
                    .foregroundColor(DesignToken.Colors.textPrimary)

                // Description
                Text("需要麦克风权限来录制您的语音")
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

                // Explanation text
                VStack(alignment: .leading, spacing: 8) {
                    Text("为什么需要此权限？")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignToken.Colors.textPrimary)

                    Text("• 实时录制您的语音输入")
                        .font(DesignToken.Typography.caption)
                        .foregroundColor(DesignToken.Colors.textSecondary)

                    Text("• 将音频发送到语音识别引擎")
                        .font(DesignToken.Typography.caption)
                        .foregroundColor(DesignToken.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)

                Spacer()

                // Action buttons
                VStack(spacing: 12) {
                    if permissionStatus != .granted {
                        Button(action: requestPermission) {
                            Text(isRequesting ? "请求中..." : "授予权限")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(DesignToken.Colors.primary)
                                .foregroundColor(.white)
                                .cornerRadius(DesignToken.CornerRadius.small)
                        }
                        .buttonStyle(.plain)
                        .disabled(isRequesting)
                    }

                    Button(action: onNext) {
                        Text(permissionStatus == .granted ? "继续" : "跳过")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(permissionStatus == .granted ? DesignToken.Colors.accent : Color.gray.opacity(0.3))
                            .foregroundColor(permissionStatus == .granted ? .white : DesignToken.Colors.textSecondary)
                            .cornerRadius(DesignToken.CornerRadius.small)
                    }
                    .buttonStyle(.plain)

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
            // 启动轮询：处理用户先拒绝再去系统设置手动开启的场景
            poller.startPolling(for: .microphone) {
                permissionStatus = .granted
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
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized: permissionStatus = .granted
        case .denied, .restricted: permissionStatus = .denied
        default: permissionStatus = .undetermined
        }
    }

    private func requestPermission() {
        isRequesting = true
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                isRequesting = false
                permissionStatus = granted ? .granted : .denied
                if granted {
                    poller.stopPolling()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onNext()
                    }
                }
            }
        }
    }

    // MARK: - Status Computed Properties

    private var statusIcon: String {
        switch permissionStatus {
        case .granted: return "checkmark.circle.fill"
        case .denied: return "xmark.circle.fill"
        case .undetermined: return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch permissionStatus {
        case .granted: return DesignToken.Colors.accent
        case .denied: return DesignToken.Colors.error
        case .undetermined: return DesignToken.Colors.warning
        }
    }

    private var statusText: String {
        switch permissionStatus {
        case .granted: return "已授权"
        case .denied: return "已拒绝 - 可在系统设置中修改"
        case .undetermined: return "未设置"
        }
    }
}

// MARK: - Preview
#Preview {
    MicrophonePermissionView(onNext: {}, onBack: {})
        .frame(width: 680, height: 540)
}
