import AppKit
import SwiftUI

final class OverlayPanel {
    private var panel: NSPanel?
    private var recordingTimer: Timer?
    private var recordingDuration: TimeInterval = 0
    private var currentVolume: Double = 0.0

    enum State {
        case recording(text: String)  // 录音中，显示实时文字
        case processing
        case done
        case hidden
    }

    private var currentState: State = .hidden

    init() {}

    func updateVolume(_ volume: Double) {
        currentVolume = volume
        if case .recording = currentState {
            updateContent()
        }
    }

    func showRecording(partialText: String = "") {
        startRecordingTimer()
        show(state: .recording(text: partialText))
    }

    func updateRecordingText(_ text: String) {
        if case .recording = currentState {
            show(state: .recording(text: text))
        }
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

        // 获取实际的转录文字用于计算尺寸
        let actualText: String
        switch state {
        case .recording(let text):
            actualText = text
        default:
            actualText = ""
        }

        let width = calculateWidth(for: actualText)

        if panel == nil {
            createPanel(width: width, text: actualText)
        } else {
            updatePanelFrame(width: width, text: actualText)
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
        // Icon: ~16pt, spacing: 8pt, padding: 16pt * 2 = 32pt
        let iconWidth: CGFloat = 16
        let spacing: CGFloat = 8
        let horizontalPadding: CGFloat = 32
        let calculatedWidth = textSize.width + iconWidth + spacing + horizontalPadding

        // Minimum and maximum constraints - 增大范围
        let minWidth: CGFloat = 300
        let maxWidth: CGFloat = 600

        return max(minWidth, min(maxWidth, calculatedWidth))
    }

    private func calculateHeight(for text: String, isRecording: Bool) -> CGFloat {
        if !isRecording {
            return 44  // 非录音状态保持紧凑
        }

        // 录音状态：根据文字行数动态调整
        let lineCount = max(1, min(6, text.components(separatedBy: "\n").count + text.count / 40))
        let baseHeight: CGFloat = 60  // 状态栏高度
        let lineHeight: CGFloat = 22  // 每行文字高度
        return baseHeight + CGFloat(lineCount) * lineHeight
    }

    private func createPanel(width: CGFloat, text: String) {
        let panelHeight = calculateHeight(for: text, isRecording: true)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.minY + 100  // 屏幕底部，距离底部 100pt

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

    private func updatePanelFrame(width: CGFloat, text: String) {
        guard let panel, let screen = NSScreen.main else { return }

        let panelHeight = calculateHeight(for: text, isRecording: true)
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - width / 2
        let y = screenFrame.minY + 100  // 屏幕底部，距离底部 100pt

        // Animate the frame change for smooth transitions
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(NSRect(x: x, y: y, width: width, height: panelHeight), display: true)
        }
    }

    private func calculateHeightForCurrentState() -> CGFloat {
        switch currentState {
        case .recording(let text):
            return calculateHeight(for: text, isRecording: true)
        case .processing, .done:
            return 44
        case .hidden:
            return 44
        }
    }


    private func updateContent() {
        // 确保在主线程执行
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateContent()
            }
            return
        }

        guard let panel else { return }

        let view: NSView
        switch currentState {
        case .recording(let text):
            let minutes = Int(recordingDuration) / 60
            let seconds = Int(recordingDuration) % 60
            let durationText = String(format: "%02d:%02d", minutes, seconds)
            let displayText = text.isEmpty ? "录音中..." : text

            // 获取当前场景信息（安全访问）
            let currentScene: SceneType
            let isAutoDetected: Bool
            if let sceneManager = SceneManager.shared as SceneManager? {
                currentScene = sceneManager.manualOverride ?? sceneManager.currentScene
                isAutoDetected = sceneManager.isAutoDetectEnabled && sceneManager.manualOverride == nil
            } else {
                currentScene = .general
                isAutoDetected = false
            }

            view = NSHostingView(rootView: EnhancedOverlayContentView(
                icon: "circle.fill",
                iconColor: .red,
                text: displayText,
                duration: durationText,
                volume: currentVolume,
                sceneType: currentScene,
                sceneAutoDetected: isAutoDetected
            ))
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

private struct EnhancedOverlayContentView: View {
    let icon: String
    let iconColor: Color
    let text: String
    let duration: String
    let volume: Double
    let sceneType: SceneType
    let sceneAutoDetected: Bool

    private var showLowVolumeWarning: Bool {
        volume < 0.15
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：录音状态 + 场景 + 时长
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 16))
                Text("录音中")
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))

                // 场景标签
                HStack(spacing: 4) {
                    Image(systemName: sceneType.icon)
                        .font(.system(size: 10))
                    Text(sceneType.displayName)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(sceneColor.opacity(0.6))
                )

                Spacer()
                Text(duration)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
            }

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            // 转录文字区域（动态高度）
            Text(text.isEmpty || text == "录音中..." ? "等待语音输入..." : text)
                .foregroundColor(text.isEmpty || text == "录音中..." ? .white.opacity(0.5) : .white)
                .font(.system(size: 14))
                .lineLimit(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sceneColor: Color {
        switch sceneType {
        case .social: return .blue
        case .coding: return .purple
        case .writing: return .orange
        case .general: return .gray
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
