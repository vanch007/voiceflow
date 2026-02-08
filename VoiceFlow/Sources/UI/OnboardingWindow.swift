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

    @State private var currentStep: OnboardingStep = .microphone

    enum OnboardingStep: CaseIterable {
        case microphone
        case accessibility
        case hotkeyPractice
        case completion
    }

    /// 当前流程中实际需要展示的步骤（跳过已授权的）
    private var activeSteps: [OnboardingStep] {
        var steps: [OnboardingStep] = []
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
        VStack(spacing: 0) {
            // Progress indicator — 动态调整为实际步骤数
            HStack(spacing: 8) {
                ForEach(0..<activeSteps.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentActiveIndex ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 10)

            // Current step view
            Group {
                switch currentStep {
                case .microphone:
                    MicrophonePermissionView(
                        onNext: {
                            advanceToNextStep(from: .microphone)
                        },
                        onBack: {
                            // 第一步无需返回
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // 初始化时检查麦克风权限，已授权则跳过
            if PermissionManager.shared.checkMicrophonePermission() == .granted {
                advanceToNextStep(from: .microphone)
            }
        }
    }

    /// 步骤切换时检查下一步是否可跳过
    private func advanceToNextStep(from current: OnboardingStep) {
        switch current {
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
