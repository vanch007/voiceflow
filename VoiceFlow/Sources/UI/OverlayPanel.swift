import AppKit
import SwiftUI

final class OverlayPanel {
    private var panel: NSPanel?

    enum State {
        case recording
        case processing
        case done
        case hidden
    }

    private var currentState: State = .hidden

    init() {}

    func showRecording() {
        show(state: .recording)
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

        let text = textForState(state)
        let width = calculateWidth(for: text)

        if panel == nil {
            createPanel(width: width)
        } else {
            updatePanelFrame(width: width)
        }

        updateContent()
        panel?.orderFront(nil)
    }

    private func textForState(_ state: State) -> String {
        switch state {
        case .recording: return "녹음 중..."
        case .processing: return "인식 중..."
        case .done: return "완료"
        case .hidden: return ""
        }
    }

    private func calculateWidth(for text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)

        // Width = text width + icon size + spacing + horizontal padding
        // Icon: ~14pt, spacing: 8pt, padding: 16pt * 2 = 32pt
        let iconWidth: CGFloat = 14
        let spacing: CGFloat = 8
        let horizontalPadding: CGFloat = 32
        let calculatedWidth = textSize.width + iconWidth + spacing + horizontalPadding

        // Minimum and maximum constraints
        let minWidth: CGFloat = 100
        let maxWidth: CGFloat = 400

        return max(minWidth, min(maxWidth, calculatedWidth))
    }

    private func createPanel(width: CGFloat) {
        let panelHeight: CGFloat = 44

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - panelHeight - 20

        let frame = NSRect(x: x, y: y, width: width, height: panelHeight)

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

    private func updatePanelFrame(width: CGFloat) {
        guard let panel, let screen = NSScreen.main else { return }

        let panelHeight: CGFloat = 44
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.maxY - panelHeight - 20

        panel.setFrame(NSRect(x: x, y: y, width: width, height: panelHeight), display: true)
    }

    private func updateContent() {
        guard let panel else { return }

        let view: NSView
        switch currentState {
        case .recording:
            view = NSHostingView(rootView: OverlayContentView(
                icon: "circle.fill",
                iconColor: .red,
                text: "녹음 중..."
            ))
        case .processing:
            view = NSHostingView(rootView: OverlayContentView(
                icon: "hourglass",
                iconColor: .yellow,
                text: "인식 중..."
            ))
        case .done:
            view = NSHostingView(rootView: OverlayContentView(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                text: "완료"
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
