import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager = .shared) {
        self.settingsManager = settingsManager
    }

    func show() {
        if window == nil {
            createWindow()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func createWindow() {
        let windowWidth: CGFloat = 500
        let windowHeight: CGFloat = 850

        let contentView = NSHostingView(
            rootView: SettingsContentView(settingsManager: settingsManager)
        )

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "设置"
        w.contentView = contentView
        w.center()
        w.isReleasedWhenClosed = false
        w.level = .normal

        window = w
    }
}

private struct SettingsContentView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var systemAudioSettings = SystemAudioSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("启用长按 Option 录音", isOn: $settingsManager.hotkeyEnabled)
                Text("长按左侧或右侧 Option (⌥) 键开始录音，松开停止")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("热键设置")
            } footer: {
                Text("关闭后将无法通过热键触发录音功能")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("识别模型")
                        .font(.headline)

                    Picker("", selection: $settingsManager.modelSize) {
                        ForEach(ModelSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            } header: {
                Text("模型选择")
            } footer: {
                Text("1.7B 模型识别更准确，0.6B 模型速度更快。修改后下次录音生效。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Picker("识别语言", selection: $settingsManager.asrLanguage) {
                    ForEach(ASRLanguage.allCases, id: \.self) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text("语言设置")
            } footer: {
                Text("选择「自动检测」可让模型自动识别语言，或指定特定语言以提高准确率。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("时间戳断句", isOn: $settingsManager.useTimestamps)
                Text("根据语音停顿时长自动插入标点符号")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("断句优化")
            } footer: {
                Text("长停顿插入句号，中停顿插入逗号，使文本断句更自然")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("实时降噪", isOn: $settingsManager.enableDenoise)
                Text("使用频谱门控算法消除环境噪音")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("音频处理")
            } footer: {
                Text("在嘈杂环境下可提升识别准确率，延迟仅约 2ms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Toggle("开机自动启动", isOn: $settingsManager.autoLaunchEnabled)
                Text("启用后，应用将在您登录 macOS 时自动启动")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("启动选项")
            } footer: {
                Text("您可以在系统设置 → 通用 → 登录项中管理此权限")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("字幕字体大小")
                        Spacer()
                        Text("\(Int(systemAudioSettings.subtitleFontSize)) pt")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $systemAudioSettings.subtitleFontSize, in: 18...24, step: 1)

                    HStack {
                        Text("背景透明度")
                        Spacer()
                        Text("\(Int(systemAudioSettings.subtitleBackgroundOpacity * 100))%")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $systemAudioSettings.subtitleBackgroundOpacity, in: 0.6...0.8, step: 0.05)

                    Picker("最大行数", selection: $systemAudioSettings.subtitleMaxLines) {
                        ForEach(1...5, id: \.self) { count in
                            Text("\(count) 行").tag(count)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("转录文件存储路径")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(systemAudioSettings.transcriptStoragePath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .truncationMode(.middle)

                    Button("打开转录文件夹") {
                        systemAudioSettings.openTranscriptFolder()
                    }
                    .buttonStyle(.bordered)
                }
            } header: {
                Text("系统音频转录")
            } footer: {
                Text("配置系统音频字幕的显示样式和转录文件存储位置")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 500, height: 850)
    }
}
