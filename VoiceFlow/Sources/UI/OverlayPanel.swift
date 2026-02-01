import AppKit
import SwiftUI

final class OverlayPanel {
    private var panel: NSPanel?
    private var recordingTimer: Timer?
    private var recordingDuration: TimeInterval = 0

    enum State {
        case recording
        case processing
        case done
        case hidden
    }

    private var currentState: State = .hidden

    init() {}

    func showRecording() {
        startRecordingTimer()
        show(state: .recording)
    }

    func showProcessing() {
        stopRecordingTimer()
        show(state: .processing)
    }

    func showDone() {
        show(state: .done)
    }

    func hide() {
        stopRecordingTimer()
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

    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer?.invalidate()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRecordingDuration()
        }
    }

    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }

    private func updateRecordingDuration() {
        recordingDuration += 0.1
        updateContent()
    }

    private func updateContent() {
        guard let panel else { return }

        let view: NSView
        switch currentState {
        case .recording:
            let durationText = String(format: "녹음 중... %.1fs", recordingDuration)
            view = NSHostingView(rootView: OverlayContentView(
                icon: "circle.fill",
                iconColor: .red,
                text: durationText
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
