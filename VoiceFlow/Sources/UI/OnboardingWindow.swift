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

        // Multi-step onboarding content view
        let contentView = OnboardingContentView(onComplete: { [weak self] in
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

// MARK: - Onboarding Content View
private struct OnboardingContentView: View {
    let onComplete: () -> Void

    @State private var currentStep: OnboardingStep = .welcome

    enum OnboardingStep {
        case welcome
        case microphone
        case accessibility
        case hotkeyPractice
        case completion
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index <= stepIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)

            // Current step view
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeView(onNext: {
                        currentStep = .microphone
                    })
                case .microphone:
                    MicrophonePermissionView(
                        onNext: {
                            currentStep = .accessibility
                        },
                        onBack: {
                            currentStep = .welcome
                        }
                    )
                case .accessibility:
                    AccessibilityPermissionView(
                        onNext: {
                            currentStep = .hotkeyPractice
                        },
                        onBack: {
                            currentStep = .microphone
                        }
                    )
                case .hotkeyPractice:
                    HotkeyPracticeView(
                        onNext: {
                            currentStep = .completion
                        },
                        onBack: {
                            currentStep = .accessibility
                        }
                    )
                case .completion:
                    CompletionView(onComplete: onComplete)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stepIndex: Int {
        switch currentStep {
        case .welcome: return 0
        case .microphone: return 1
        case .accessibility: return 2
        case .hotkeyPractice: return 3
        case .completion: return 4
        }
    }
}
