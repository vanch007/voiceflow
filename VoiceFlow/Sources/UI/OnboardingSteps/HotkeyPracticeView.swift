import SwiftUI
import AppKit

/// Hotkey Practice screen (Step 4) - Interactive demonstration of hotkey functionality
struct HotkeyPracticeView: View {
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var hasDetectedHotkey = false
    @State private var detectionCount = 0
    @State private var lastDetectionTime: Date?
    @State private var hotkeyManager: HotkeyManager?

    // 动态读取当前热键配置
    private var voiceInputConfig: HotkeyConfig {
        if let data = UserDefaults.standard.data(forKey: "voiceflow.hotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            return config
        }
        return HotkeyConfig.default
    }

    private var systemAudioConfig: HotkeyConfig {
        if let data = UserDefaults.standard.data(forKey: "voiceflow.systemAudioHotkeyConfig"),
           let config = try? JSONDecoder().decode(HotkeyConfig.self, from: data) {
            return config
        }
        return HotkeyConfig.systemAudioDefault
    }

    private var voiceInputInstruction: String {
        switch voiceInputConfig.triggerType {
        case .longPress:
            return "按住 \(voiceInputConfig.displayString.replacingOccurrences(of: " 长按", with: "")) 键开始录音，释放后停止"
        case .doubleTap:
            return "快速按下并释放 \(voiceInputConfig.displayString.replacingOccurrences(of: " 双击", with: "")) 键两次开始录音"
        default:
            return "使用 \(voiceInputConfig.displayString) 触发录音"
        }
    }

    private var encouragementText: String {
        return "现在试试 \(voiceInputConfig.displayString)"
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Keyboard icon
            Image(systemName: "keyboard.fill")
                .font(.system(size: 80))
                .foregroundColor(hasDetectedHotkey ? .green : .blue)
                .animation(.easeInOut(duration: 0.3), value: hasDetectedHotkey)

            // Title
            Text("热键练习")
                .font(.system(size: 28, weight: .bold))

            // Description
            Text("尝试使用热键启动录音功能")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
                .frame(height: 20)

            // Detection status indicator
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
            .background(statusBackgroundColor.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 40)
            .animation(.easeInOut(duration: 0.3), value: hasDetectedHotkey)

            Spacer()

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("如何使用热键：")
                    .font(.system(size: 14, weight: .medium))

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("语音输入: \(voiceInputConfig.displayString)")
                            .font(.system(size: 13, weight: .medium))

                        Text(voiceInputInstruction)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("系统音频: \(systemAudioConfig.displayString)")
                            .font(.system(size: 13, weight: .medium))

                        Text("录制电脑播放的声音并生成字幕")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            // Encouragement text
            if !hasDetectedHotkey {
                HStack(spacing: 8) {
                    Image(systemName: "hand.point.up.left.fill")
                        .foregroundColor(.orange)

                    Text(encouragementText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("很好！您已经掌握了热键操作")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 40)
            }

            Spacer()

            // Action buttons
            VStack(spacing: 12) {
                Button(action: onNext) {
                    Text(hasDetectedHotkey ? "继续" : "跳过")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasDetectedHotkey ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundColor(hasDetectedHotkey ? .white : .primary)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                if hasDetectedHotkey {
                    Text("检测次数: \(detectionCount)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Button(action: onBack) {
                    Text("返回")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupHotkeyDetection()
        }
        .onDisappear {
            cleanupHotkeyDetection()
        }
    }

    // MARK: - Hotkey Detection Setup

    private func setupHotkeyDetection() {
        // Create a temporary HotkeyManager instance for practice
        let manager = HotkeyManager()

        // Set up callback for hotkey detection (long-press trigger)
        manager.onLongPress = { [self] in
            DispatchQueue.main.async {
                self.hasDetectedHotkey = true
                self.detectionCount += 1
                self.lastDetectionTime = Date()

                // Provide haptic/visual feedback
                NSSound.beep()
            }
        }

        // Start listening for hotkeys
        manager.start()

        // Store reference
        hotkeyManager = manager
    }

    private func cleanupHotkeyDetection() {
        // HotkeyManager cleanup happens in deinit
        hotkeyManager = nil
    }

    // MARK: - Status Computed Properties

    private var statusIcon: String {
        if hasDetectedHotkey {
            return "checkmark.circle.fill"
        } else {
            return "circle.dashed"
        }
    }

    private var statusColor: Color {
        hasDetectedHotkey ? .green : .orange
    }

    private var statusBackgroundColor: Color {
        hasDetectedHotkey ? .green : .gray
    }

    private var statusText: String {
        if hasDetectedHotkey {
            if let lastTime = lastDetectionTime {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss"
                return "热键已检测 - \(formatter.string(from: lastTime))"
            }
            return "热键已检测"
        } else {
            return "等待热键操作..."
        }
    }
}

// MARK: - Preview
#Preview {
    HotkeyPracticeView(onNext: {}, onBack: {})
        .frame(width: 600, height: 500)
}
