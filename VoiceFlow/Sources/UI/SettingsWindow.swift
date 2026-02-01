import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?
    private let settingsManager: SettingsManager

    init(settingsManager: SettingsManager) {
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
        let windowHeight: CGFloat = 400

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

    var body: some View {
        Form {
            Section(header: Text("热键设置")) {
                Toggle("启用双击 Control 录音", isOn: $settingsManager.hotkeyEnabled)
            }

            Section(header: Text("模型选择")) {
                Picker("识别模型", selection: $settingsManager.modelSize) {
                    ForEach(ModelSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section(header: Text("启动选项")) {
                Toggle("开机自动启动", isOn: $settingsManager.autoLaunchEnabled)
                Text("需要您的明确同意才会在登录时自动启动应用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 500, height: 400)
    }
}
