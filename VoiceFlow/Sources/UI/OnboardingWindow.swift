import AppKit
import SwiftUI

final class OnboardingWindow: NSObject {
    private var window: NSWindow?
    private var onComplete: (() -> Void)?

    init() {
        super.init()
    }

    func show(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete

        if window == nil {
            createWindow()
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
        window = nil
        onComplete = nil
    }

    private func createWindow() {
        let windowWidth: CGFloat = 600
        let windowHeight: CGFloat = 500

        let frame = NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight)

        let w = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.center()
        w.title = "欢迎使用 VoiceFlow"
        w.level = .floating
        w.isReleasedWhenClosed = false
        w.delegate = self

        // Temporary placeholder view - will be replaced with OnboardingContentView
        let contentView = OnboardingPlaceholderView(onComplete: { [weak self] in
            self?.handleComplete()
        })

        w.contentView = NSHostingView(rootView: contentView)

        window = w
    }

    private func handleComplete() {
        onComplete?()
        close()
    }
}

// MARK: - NSWindowDelegate
extension OnboardingWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        window = nil
        onComplete = nil
    }
}

// MARK: - Placeholder View
private struct OnboardingPlaceholderView: View {
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("欢迎使用 VoiceFlow")
                .font(.system(size: 24, weight: .bold))

            Text("语音转文字助手")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Spacer()

            Text("Onboarding steps will be added in Phase 3")
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onComplete) {
                Text("完成")
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
