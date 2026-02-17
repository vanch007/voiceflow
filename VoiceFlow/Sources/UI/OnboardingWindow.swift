import AppKit
import SwiftUI

final class OnboardingWindow: NSObject {
    private var window: NSWindow?
    private var onComplete: (() -> Void)?

    override init() {
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
        let windowWidth: CGFloat = 680
        let windowHeight: CGFloat = 540

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

    enum OnboardingStep: CaseIterable {
        case welcome
        case microphone
        case accessibility
        case hotkeyPractice
        case completion
    }

    /// 当前流程中实际需要展示的步骤（跳过已授权的）
    private var activeSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = []
        steps.append(.welcome)  // 欢迎页始终显示
        if PermissionManager.shared.checkMicrophonePermission() != .granted {
            steps.append(.microphone)
        }
        if PermissionManager.shared.checkAccessibilityPermission() != .granted {
            steps.append(.accessibility)
        }
        steps.append(.hotkeyPractice)
        steps.append(.completion)
        return steps
    }

    var body: some View {
        ZStack {
            GradientBackground()
            VStack(spacing: 0) {
                // Animated Progress Bar using DesignSystem
                AnimatedProgressBar(currentStep: currentActiveIndex, totalSteps: activeSteps.count)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    .padding(.horizontal, 8)

                // Current step view with transition animation
                Group {
                    switch currentStep {
                    case .welcome:
                        WelcomeView(
                            onNext: {
                                advanceToNextStep(from: .welcome)
                            }
                        )
                    case .microphone:
                        MicrophonePermissionView(
                            onNext: {
                                advanceToNextStep(from: .microphone)
                            },
                            onBack: {
                                currentStep = .welcome
                            }
                        )
                    case .accessibility:
                        AccessibilityPermissionView(
                            onNext: {
                                advanceToNextStep(from: .accessibility)
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 步骤切换时检查下一步是否可跳过
    private func advanceToNextStep(from current: OnboardingStep) {
        switch current {
        case .welcome:
            if PermissionManager.shared.checkMicrophonePermission() == .granted {
                if PermissionManager.shared.checkAccessibilityPermission() == .granted {
                    currentStep = .hotkeyPractice
                } else {
                    currentStep = .accessibility
                }
            } else {
                currentStep = .microphone
            }
        case .microphone:
            if PermissionManager.shared.checkAccessibilityPermission() == .granted {
                currentStep = .hotkeyPractice
            } else {
                currentStep = .accessibility
            }
        case .accessibility:
            currentStep = .hotkeyPractice
        case .hotkeyPractice:
            currentStep = .completion
        case .completion:
            break
        }
    }

    /// 当前步骤在活跃步骤列表中的索引
    private var currentActiveIndex: Int {
        activeSteps.firstIndex(of: currentStep) ?? 0
    }
}
