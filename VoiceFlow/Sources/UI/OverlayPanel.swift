import AppKit
import SwiftUI

final class OverlayPanel {
    private var panel: NSPanel?
    private var recordingTimer: Timer?
    private var recordingDuration: TimeInterval = 0
    private var currentVolume: Double = 0.0
    private var isFreeSpeakMode: Bool = false
    private var silenceCountdown: TimeInterval = 0
    private var silenceThreshold: TimeInterval = 2.0
    private var currentSNR: Float = 0.0
    private var signalQuality: SignalQualityLevel = .good
    private var cursorPosition: CursorTracker.CursorPosition?

    /// 悬浮窗定位模式
    enum PositionMode {
        case followCursor    // 跟随光标
        case screenBottom    // 屏幕底部（回退）
    }

    private var positionMode: PositionMode = .screenBottom

    enum SignalQualityLevel {
        case excellent  // SNR >= 20dB - 绿色
        case good       // SNR >= 10dB - 黄色
        case poor       // SNR < 10dB - 红色

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .yellow
            case .poor: return .red
            }
        }

        var description: String {
            switch self {
            case .excellent: return "信号优秀"
            case .good: return "信号良好"
            case .poor: return "信号较弱"
            }
        }
    }

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

    func updateSNR(_ snr: Float) {
        currentSNR = snr
        if snr >= 20 {
            signalQuality = .excellent
        } else if snr >= 10 {
            signalQuality = .good
        } else {
            signalQuality = .poor
        }
        if case .recording = currentState {
            updateContent()
        }
    }

    func updateSilenceCountdown(_ current: TimeInterval, threshold: TimeInterval) {
        silenceCountdown = current
        silenceThreshold = threshold
        if case .recording = currentState, isFreeSpeakMode {
            updateContent()
        }
    }

    func setFreeSpeakMode(_ enabled: Bool) {
        isFreeSpeakMode = enabled
        silenceCountdown = 0
    }

    func showRecording(partialText: String = "") {
        // 录音开始时获取光标位置
        cursorPosition = CursorTracker.shared.getCurrentCursorPosition()
        positionMode = cursorPosition?.isValid == true ? .followCursor : .screenBottom
        NSLog("[OverlayPanel] 光标位置: \(cursorPosition?.rect ?? .zero), isValid: \(cursorPosition?.isValid ?? false), 模式: \(positionMode == .followCursor ? "跟随光标" : "屏幕底部")")
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
        // 基础宽度 + 根据文字长度动态调整
        let baseWidth: CGFloat = 280
        let maxWidth: CGFloat = 500

        if text.isEmpty {
            return baseWidth
        }

        let font = NSFont.systemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attributes)

        return min(maxWidth, max(baseWidth, textSize.width + 60))
    }

    private func calculateHeight(for text: String, isRecording: Bool) -> CGFloat {
        if !isRecording {
            return 44
        }
        // 状态栏 + 分隔线 + 文字区域
        let baseHeight: CGFloat = 80
        if text.isEmpty {
            return baseHeight
        }
        let lineCount = max(1, min(4, text.count / 30 + 1))
        return baseHeight + CGFloat(lineCount - 1) * 20
    }

    private func createPanel(width: CGFloat, text: String) {
        let panelHeight = calculateHeight(for: text, isRecording: true)

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let (x, y) = calculatePanelPosition(
            width: width,
            height: panelHeight,
            screenFrame: screenFrame
        )

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

    /// 计算悬浮窗位置
    private func calculatePanelPosition(width: CGFloat, height: CGFloat, screenFrame: CGRect) -> (CGFloat, CGFloat) {
        switch positionMode {
        case .followCursor:
            guard let cursorPos = cursorPosition, cursorPos.isValid else {
                // 回退到屏幕底部
                return calculateScreenBottomPosition(width: width, screenFrame: screenFrame)
            }

            let cursorRect = cursorPos.rect
            let padding: CGFloat = 8

            // 悬浮窗左边对齐光标位置
            var x = cursorRect.origin.x
            // 确保不超出屏幕边界
            x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - width - 10))

            // 优先在光标下方显示
            var y = cursorRect.origin.y - height - padding

            // 如果超出屏幕底部，改为光标上方
            if y < screenFrame.minY {
                y = cursorRect.origin.y + cursorRect.height + padding
            }

            // 如果还是超出屏幕顶部，回退到屏幕底部
            if y + height > screenFrame.maxY {
                return calculateScreenBottomPosition(width: width, screenFrame: screenFrame)
            }

            NSLog("[OverlayPanel] 悬浮窗位置: x=\(x), y=\(y), 光标位置: \(cursorRect)")
            return (x, y)

        case .screenBottom:
            return calculateScreenBottomPosition(width: width, screenFrame: screenFrame)
        }
    }

    private func calculateScreenBottomPosition(width: CGFloat, screenFrame: CGRect) -> (CGFloat, CGFloat) {
        let x = screenFrame.midX - width / 2
        let y = screenFrame.minY + 100
        return (x, y)
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

        let (x, y) = calculatePanelPosition(
            width: width,
            height: panelHeight,
            screenFrame: screenFrame
        )

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

            // 获取当前场景信息（安全访问）
            let currentScene: SceneType
            if let sceneManager = SceneManager.shared as SceneManager? {
                currentScene = sceneManager.manualOverride ?? sceneManager.currentScene
            } else {
                currentScene = .general
            }

            view = NSHostingView(rootView: EnhancedOverlayContentView(
                text: text,
                duration: durationText,
                volume: currentVolume,
                sceneType: currentScene,
                signalQuality: signalQuality
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
    let text: String
    let duration: String
    let volume: Double
    let sceneType: SceneType
    let signalQuality: OverlayPanel.SignalQualityLevel

    @State private var isPulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 第一行：录音动画 + 场景 + 音量波形 + 时长
            HStack(spacing: 10) {
                // 脉冲动画录音图标
                ZStack {
                    Circle()
                        .stroke(Color.red.opacity(0.4), lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .scaleEffect(isPulsing ? 1.5 : 1.0)
                        .opacity(isPulsing ? 0 : 0.6)

                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
                .frame(width: 18)
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: 1.0)
                        .repeatForever(autoreverses: false)
                    ) {
                        isPulsing = true
                    }
                }

                // 场景标签
                HStack(spacing: 3) {
                    Image(systemName: sceneType.icon)
                        .font(.system(size: 9))
                    Text(sceneType.displayName)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(sceneColor.opacity(0.6))
                )

                Spacer()

                // 音量波形
                VolumeWaveformView(volume: volume, signalQuality: signalQuality)
                    .frame(width: 36, height: 14)

                // 时长
                Text(duration)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 14, weight: .semibold))
                    .monospacedDigit()
            }

            // 分隔线
            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            // 实时转录文字
            Text(text.isEmpty ? "等待语音..." : text)
                .foregroundColor(text.isEmpty ? .white.opacity(0.4) : .white)
                .font(.system(size: 13))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.88))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sceneColor: Color {
        switch sceneType {
        case .social: return .blue
        case .coding: return .purple
        case .writing: return .orange
        case .general: return .gray
        case .medical: return .green
        case .legal: return .brown
        case .technical: return .cyan
        case .finance: return .yellow
        case .engineering: return .red
        }
    }
}

/// 音量波形可视化组件
private struct VolumeWaveformView: View {
    let volume: Double
    let signalQuality: OverlayPanel.SignalQualityLevel

    private let barCount = 5

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: volume)
            }
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 18

        // 创建对称的波形效果，中间最高
        let middleIndex = Double(barCount - 1) / 2.0
        let distance = abs(Double(index) - middleIndex)
        let positionMultiplier = 1.0 - (distance / middleIndex) * 0.3

        // 根据音量计算高度
        let volumeHeight = baseHeight + (maxHeight - baseHeight) * volume * positionMultiplier

        return max(baseHeight, volumeHeight)
    }

    private func barColor(for index: Int) -> Color {
        let threshold = volume * Double(barCount)
        if Double(index) < threshold {
            return signalQuality.color
        } else {
            return Color.white.opacity(0.2)
        }
    }
}
