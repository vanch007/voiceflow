import AppKit
import SwiftUI

final class OverlayPanel {
    private var panel: NSPanel?
    private var recordingTimer: Timer?
    private var recordingDuration: TimeInterval = 0
    private var currentVolume: Double = 0.0

    enum State {
        case recording
        case processing
        case done
        case hidden
    }

    private var currentState: State = .hidden

    init() {}

    func updateVolume(_ volume: Double) {
        currentVolume = volume
        if currentState == .recording {
            updateContent()
        }
    }

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
        let panelWidth: CGFloat = 280
        let panelHeight: CGFloat = 100

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
            let minutes = Int(recordingDuration) / 60
            let seconds = Int(recordingDuration) % 60
            let durationText = String(format: "%02d:%02d", minutes, seconds)
            view = NSHostingView(rootView: EnhancedOverlayContentView(
                icon: "circle.fill",
                iconColor: .red,
                text: "녹음 중",
                duration: durationText,
                volume: currentVolume
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

private struct EnhancedOverlayContentView: View {
    let icon: String
    let iconColor: Color
    let text: String
    let duration: String
    let volume: Double

    private var showLowVolumeWarning: Bool {
        volume < 0.15
    }

    var body: some View {
        VStack(spacing: 8) {
            // Status and duration row
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14))
                Text(text)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
                Text(duration)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 16, weight: .semibold))
                    .monospacedDigit()
            }

            // Volume indicator
            HStack(spacing: 8) {
                Image(systemName: volumeIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .frame(width: 16)

                // Volume bars
                HStack(spacing: 2) {
                    ForEach(0..<10, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(barColor(for: index))
                            .frame(width: 3, height: barHeight(for: index))
                    }
                }

                Spacer()

                // Low volume warning
                if showLowVolumeWarning {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10))
                        Text("음량 낮음")
                            .foregroundColor(.yellow)
                            .font(.system(size: 10, weight: .medium))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var volumeIcon: String {
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.fill"
        } else if volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 6
        let maxHeight: CGFloat = 14
        let middleIndex = 5

        let distance = abs(Double(index - middleIndex))
        let heightMultiplier = 1.0 - (distance / 5.0) * 0.3

        return baseHeight + (maxHeight - baseHeight) * heightMultiplier
    }

    private func barColor(for index: Int) -> Color {
        let threshold = volume * 10.0
        if Double(index) < threshold {
            // Active bars
            if volume > 0.7 {
                return .green
            } else if volume > 0.3 {
                return .yellow
            } else {
                return .orange
            }
        } else {
            // Inactive bars
            return Color.white.opacity(0.2)
        }
    }
}

struct VolumeIndicatorView: View {
    let volume: Double // 0.0 to 1.0

    private var volumeIcon: String {
        if volume == 0 {
            return "speaker.slash.fill"
        } else if volume < 0.33 {
            return "speaker.fill"
        } else if volume < 0.66 {
            return "speaker.wave.1.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: volumeIcon)
                .foregroundColor(.white)
                .font(.system(size: 14))
                .frame(width: 20)

            // Volume bars
            HStack(spacing: 3) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(barColor(for: index))
                        .frame(width: 3, height: barHeight(for: index))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 20
        let middleIndex = 5

        // Create a symmetric pattern with taller bars in the middle
        let distance = abs(Double(index - middleIndex))
        let heightMultiplier = 1.0 - (distance / 5.0) * 0.4

        return baseHeight + (maxHeight - baseHeight) * heightMultiplier
    }

    private func barColor(for index: Int) -> Color {
        let threshold = volume * 10.0
        if Double(index) < threshold {
            // Active bars
            if volume > 0.8 {
                return .red
            } else if volume > 0.6 {
                return .yellow
            } else {
                return .green
            }
        } else {
            // Inactive bars
            return Color.white.opacity(0.3)
        }
    }
}

#if DEBUG
struct VolumeIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VolumeIndicatorView(volume: 0.0)
                .previewDisplayName("Muted")
            VolumeIndicatorView(volume: 0.3)
                .previewDisplayName("Low")
            VolumeIndicatorView(volume: 0.6)
                .previewDisplayName("Medium")
            VolumeIndicatorView(volume: 0.9)
                .previewDisplayName("High")
        }
        .frame(width: 200, height: 44)
        .background(Color.gray)
    }
}
#endif
