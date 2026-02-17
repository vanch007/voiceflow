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

    // Dynamic hotkey configuration reader
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
        ZStack {
            // Gradient background
            GradientBackground()

            VStack(spacing: 20) {
                Spacer()

                // Static keyboard icon
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 80))
                    .foregroundColor(hasDetectedHotkey ? DesignToken.Colors.accent : DesignToken.Colors.primary)

                // Title
                Text("热键练习")
                    .font(DesignToken.Typography.title)
                    .foregroundColor(DesignToken.Colors.textPrimary)

                // Description
                Text("尝试使用热键启动录音功能")
                    .font(DesignToken.Typography.subtitle)
                    .foregroundColor(DesignToken.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 20)

                // GlassCard wrapped status indicator
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

                // GlassCard wrapped instructions
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("如何使用热键：")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignToken.Colors.textPrimary)

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "1.circle.fill")
                                .foregroundColor(DesignToken.Colors.primary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("语音输入: \(voiceInputConfig.displayString)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignToken.Colors.textPrimary)

                                Text(voiceInputInstruction)
                                    .font(DesignToken.Typography.caption)
                                    .foregroundColor(DesignToken.Colors.textSecondary)
                            }
                        }

                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "2.circle.fill")
                                .foregroundColor(DesignToken.Colors.primary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("系统音频: \(systemAudioConfig.displayString)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignToken.Colors.textPrimary)

                                Text("录制电脑播放的声音并生成字幕")
                                    .font(DesignToken.Typography.caption)
                                    .foregroundColor(DesignToken.Colors.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 40)

                // Encouragement text
                if !hasDetectedHotkey {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.point.up.left.fill")
                            .foregroundColor(DesignToken.Colors.warning)

                        Text(encouragementText)
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.textSecondary)
                    }
                    .padding(.horizontal, 40)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignToken.Colors.accent)

                        Text("很好！您已经掌握了热键操作")
                            .font(DesignToken.Typography.caption)
                            .foregroundColor(DesignToken.Colors.accent)
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
                            .background(hasDetectedHotkey ? DesignToken.Colors.primary : Color.gray.opacity(0.3))
                            .foregroundColor(hasDetectedHotkey ? .white : DesignToken.Colors.textSecondary)
                            .cornerRadius(DesignToken.CornerRadius.small)
                    }
                    .buttonStyle(.plain)

                    if hasDetectedHotkey {
                        Text("检测次数: \(detectionCount)")
                            .font(.system(size: 11))
                            .foregroundColor(DesignToken.Colors.textSecondary)
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
        hasDetectedHotkey ? DesignToken.Colors.accent : DesignToken.Colors.warning
    }

    private var statusBackgroundColor: Color {
        hasDetectedHotkey ? DesignToken.Colors.accent : Color.gray
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
