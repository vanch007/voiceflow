import AppKit
import SwiftUI

/// 系统音频实时字幕悬浮窗
/// - 只维护一个完整文本，渲染时按标点自动拆成两行
/// - 上一行：已完成的分句（淡化显示）
/// - 当前行：正在输入的分句（高亮显示）
/// - 固定宽度，左对齐
final class SubtitlePanel {
    private var panel: NSPanel?
    private var hideTimer: Timer?

    // 字幕数据：单一文本源
    private var fullText: String = ""

    // 可配置样式
    private var fontSize: CGFloat = 20
    private var backgroundOpacity: Double = 0.75
    private let minPanelWidth: CGFloat = 300
    private let maxPanelWidth: CGFloat = 900

    // 拖动支持
    private var savedPosition: CGPoint?

    enum State {
        case showing
        case recording
        case hidden
    }

    private var currentState: State = .hidden

    // 分句用的标点符号（句号、问号、感叹号、逗号、分号等）
    private static let sentenceBreaks: Set<Character> = [
        "。", "？", "！", "；",  // 中文句终
        "，",                    // 中文逗号也可分句
        ".", "?", "!", ";", ",", // 英文标点
    ]

    init() {}

    // MARK: - Configuration

    func setFontSize(_ size: CGFloat) {
        fontSize = max(18, min(24, size))
        updateContent()
    }

    func setBackgroundOpacity(_ opacity: Double) {
        backgroundOpacity = max(0.5, min(0.9, opacity))
        updateContent()
    }

    func setMaxLines(_ lines: Int) {}

    // MARK: - Subtitle Management

    // 分行长度约束
    private static let minPrevLength = 10   // 上一行至少 10 个字符
    private static let minActiveLength = 5  // 当前行至少 5 个字符

    /// 将文本按标点拆成两行
    /// 从后往前找满足长度约束的分句标点
    /// 返回 (previousLine, activeLine)
    private static func splitIntoTwoLines(_ text: String) -> (String, String) {
        guard !text.isEmpty else { return ("", "") }

        let chars = Array(text)
        let total = chars.count
        // 跳过末尾字符（可能是标点本身）
        let searchEnd = total - 1

        // 从后往前逐个找标点，找到满足长度约束的第一个
        for i in stride(from: searchEnd - 1, through: 0, by: -1) {
            guard sentenceBreaks.contains(chars[i]) else { continue }

            let prevLen = i + 1  // 上一行长度（含标点）
            let activeStr = String(chars[(i + 1)...]).trimmingCharacters(in: .whitespaces)
            let activeLen = activeStr.count

            // 两行都满足最短长度才分割
            if prevLen >= minPrevLength && activeLen >= minActiveLength {
                let prev = String(chars[0...i])
                return (prev, activeStr)
            }
        }

        // 没有满足约束的分割点，整段作为当前行
        return ("", text)
    }

    /// 更新 partial 字幕
    func updatePartialSubtitle(_ text: String, trigger: String = "periodic") {
        guard !text.isEmpty else { return }
        fullText = text
        showPanel()
        updateContent()
    }

    /// 添加最终字幕（录制结束时的完整结果）
    func addFinalSubtitle(_ text: String) {
        guard !text.isEmpty else { return }
        fullText = text
        showPanel()
        updateContent()
        resetHideTimer()
    }

    /// 清空所有字幕
    func clearSubtitles() {
        fullText = ""
        updateContent()
    }

    /// 获取所有字幕文本
    func getAllSubtitles() -> [String] {
        guard !fullText.isEmpty else { return [] }
        let (prev, active) = Self.splitIntoTwoLines(fullText)
        var result: [String] = []
        if !prev.isEmpty { result.append(prev) }
        if !active.isEmpty { result.append(active) }
        return result
    }

    // MARK: - Panel Management

    func showRecording() {
        clearSubtitles()
        showPanel()
        currentState = .recording
        hideTimer?.invalidate()
        hideTimer = nil
    }

    func stopRecording() {
        if currentState == .recording {
            currentState = .showing
            resetHideTimer()
        }
    }

    func show() { showPanel() }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel?.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            self?.panel?.orderOut(nil)
            self?.currentState = .hidden
        }
    }

    private func showPanel() {
        if panel == nil { createPanel() }
        updateContent()
        if currentState == .hidden {
            panel?.alphaValue = 0
            panel?.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel?.animator().alphaValue = 1
            }
            currentState = .showing
        } else {
            panel?.orderFront(nil)
        }
    }

    private func createPanel() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let panelHeight: CGFloat = 90

        let x: CGFloat
        let y: CGFloat
        if let saved = savedPosition {
            x = saved.x; y = saved.y
        } else {
            x = screenFrame.midX - maxPanelWidth / 2
            y = screenFrame.minY + 60
        }

        let frame = NSRect(x: x, y: y, width: maxPanelWidth, height: panelHeight)
        let p = NSPanel(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered, defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isMovableByWindowBackground = true
        p.hidesOnDeactivate = false
        p.alphaValue = 0

        NotificationCenter.default.addObserver(
            self, selector: #selector(panelDidMove(_:)),
            name: NSWindow.didMoveNotification, object: p
        )
        panel = p
    }

    @objc private func panelDidMove(_ notification: Notification) {
        guard let p = panel else { return }
        savedPosition = CGPoint(x: p.frame.origin.x, y: p.frame.origin.y)
    }

    private func resetHideTimer() {
        guard currentState != .recording else { return }
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            self?.hide()
        }
    }

    private func updateContent() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.updateContent() }
            return
        }
        guard let panel else { return }

        let (prev, active) = Self.splitIntoTwoLines(fullText)

        let view = NSHostingView(rootView: SubtitleContentView(
            previousLine: prev,
            activeLine: active,
            fontSize: fontSize,
            backgroundOpacity: backgroundOpacity,
            isRecording: currentState == .recording,
            minWidth: minPanelWidth,
            maxWidth: maxPanelWidth
        ))

        // 计算内容实际需要的宽度，左边位置不动，右边自适应
        let fittingSize = view.fittingSize
        let newWidth = max(minPanelWidth, min(maxPanelWidth, fittingSize.width))
        let newHeight = max(70, fittingSize.height)

        let oldFrame = panel.frame
        let newFrame = NSRect(
            x: oldFrame.origin.x,
            y: oldFrame.origin.y + oldFrame.height - newHeight,
            width: newWidth,
            height: newHeight
        )
        panel.setFrame(newFrame, display: false)
        panel.contentView = view
    }

    deinit {
        hideTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - SwiftUI Views

private struct SubtitleContentView: View {
    let previousLine: String
    let activeLine: String
    let fontSize: CGFloat
    let backgroundOpacity: Double
    let isRecording: Bool
    let minWidth: CGFloat
    let maxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if previousLine.isEmpty && activeLine.isEmpty && isRecording {
                Text("等待音频...")
                    .font(.system(size: fontSize - 2, weight: .regular))
                    .foregroundColor(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                if !previousLine.isEmpty {
                    Text(previousLine)
                        .font(.system(size: fontSize, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                        .truncationMode(.head)
                }
                if !activeLine.isEmpty {
                    Text(activeLine)
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 12)
        .frame(minWidth: minWidth, maxWidth: maxWidth, alignment: .leading)
        .fixedSize(horizontal: true, vertical: false)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(backgroundOpacity))
                )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct SubtitleContentView_Previews: PreviewProvider {
    static var previews: some View {
        SubtitleContentView(
            previousLine: "他具有实际业务情况，以及对标一些初创公司去划分每一个人的职责，",
            activeLine: "以及他们的工作内容都花在这些。",
            fontSize: 20,
            backgroundOpacity: 0.75,
            isRecording: true,
            minWidth: 300,
            maxWidth: 900
        )
        .fixedSize()
        .padding()
        .background(Color.gray)
    }
}
#endif
