import SwiftUI
import AVFoundation

/// Microphone Permission screen (Step 2) - Request microphone access for audio recording
struct MicrophonePermissionView: View {
    let onNext: () -> Void

    @State private var permissionStatus: AVAudioSession.RecordPermission = .undetermined
    @State private var isRequesting = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            // Title
            Text("麦克风权限")
                .font(.system(size: 28, weight: .bold))

            // Description
            Text("需要麦克风权限来录制您的语音")
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

                Text("• 实时录制您的语音输入")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text("• 将音频发送到语音识别引擎")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
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
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isRequesting)
                }

                Button(action: onNext) {
                    Text(permissionStatus == .granted ? "继续" : "跳过")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(permissionStatus == .granted ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(permissionStatus == .granted ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
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
        permissionStatus = AVAudioSession.sharedInstance().recordPermission
    }

    private func requestPermission() {
        isRequesting = true
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                isRequesting = false
                permissionStatus = granted ? .granted : .denied
            }
        }
    }

    // MARK: - Status Computed Properties

    private var statusIcon: String {
        switch permissionStatus {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .undetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch permissionStatus {
        case .granted:
            return .green
        case .denied:
            return .red
        case .undetermined:
            return .orange
        @unknown default:
            return .orange
        }
    }

    private var statusText: String {
        switch permissionStatus {
        case .granted:
            return "已授权"
        case .denied:
            return "已拒绝 - 可在系统设置中修改"
        case .undetermined:
            return "未设置"
        @unknown default:
            return "未知状态"
        }
    }
}

// MARK: - Preview
#Preview {
    MicrophonePermissionView(onNext: {})
        .frame(width: 600, height: 500)
}
