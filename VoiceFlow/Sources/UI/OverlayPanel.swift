import AppKit
import SwiftUI

final class OverlayPanel {
    private var panel: NSPanel?

    enum State {
        case recording(text: String)  // 录音中，显示实时文字
        case processing
        case done
        case hidden
    }

    private var currentState: State = .hidden

    init() {}

    func showRecording(partialText: String = "") {
        show(state: .recording(text: partialText))
    }

    func updateRecordingText(_ text: String) {
        if case .recording = currentState {
            show(state: .recording(text: text))
        }
    }

    func showProcessing() {
        show(state: .processing)
    }

    func showDone() {
        show(state: .done)
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
        currentState = .hidden
    }

    private func show(state: State) {
        currentState = state

        if panel == nil {
            createPanel()
        }

        updateContent()
        panel?.orderFront(nil)
    }

    private func createPanel() {
        let panelWidth: CGFloat = 200
        let panelHeight: CGFloat = 44

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.maxY - panelHeight - 20

        let frame = NSRect(x: x, y: y, width: panelWidth, height: panelHeight)

        let p = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = false
        p.hidesOnDeactivate = false

        panel = p
    }

    private func updateContent() {
        guard let panel else { return }

        let view: NSView
        switch currentState {
        case .recording(let text):
            if text.isEmpty {
                // 无文字时显示录音提示
                view = NSHostingView(rootView: OverlayContentView(
                    icon: "circle.fill",
                    iconColor: .red,
                    text: "录音中..."
                ))
            } else {
                // 显示实时识别的文字
                view = NSHostingView(rootView: OverlayContentView(
                    icon: "circle.fill",
                    iconColor: .red,
                    text: text
                ))
            }
        case .processing:
            view = NSHostingView(rootView: OverlayContentView(
                icon: "hourglass",
                iconColor: .yellow,
                text: "识别中..."
            ))
        case .done:
            view = NSHostingView(rootView: OverlayContentView(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                text: "完成"
            ))
        case .hidden:
            return
        }

        panel.contentView = view
    }
}

private struct OverlayContentView: View {
    let icon: String
    let iconColor: Color
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 14))
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
