import AppKit
import SwiftUI

final class SettingsWindow {
    private var window: NSWindow?

    init() {}

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
        let windowWidth: CGFloat = 400
        let windowHeight: CGFloat = 200

        let contentRect = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        let w = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        w.title = "Settings"
        w.center()
        w.isReleasedWhenClosed = false

        let contentView = NSHostingView(rootView: SettingsContentView())
        w.contentView = contentView

        window = w
    }
}

private struct SettingsContentView: View {
    @State private var isTextPolishEnabled = UserDefaults.standard.isTextPolishEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("VoiceFlow Settings")
                .font(.system(size: 18, weight: .semibold))

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Text Polish")
                            .font(.system(size: 14, weight: .medium))

                        Text("Automatically remove filler words and improve grammar")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isTextPolishEnabled)
                        .labelsHidden()
                        .onChange(of: isTextPolishEnabled) { newValue in
                            UserDefaults.standard.isTextPolishEnabled = newValue
                        }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 200)
    }
}
