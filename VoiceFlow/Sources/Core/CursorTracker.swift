import AppKit
import ApplicationServices

/// 光标位置追踪器 - 通过 Accessibility API 获取当前输入光标的屏幕位置
/// 当 Accessibility API 无法获取精确位置时，回退到鼠标点击位置
final class CursorTracker {

    struct CursorPosition {
        let rect: CGRect           // 光标屏幕坐标
        let isValid: Bool          // 是否成功获取
        let source: PositionSource // 位置来源

        enum PositionSource {
            case accessibility     // 从 Accessibility API 获取
            case mouseClick        // 从鼠标点击位置回退
            case elementEstimate   // 从元素位置估算
        }

        static let invalid = CursorPosition(rect: .zero, isValid: false, source: .accessibility)

        init(rect: CGRect, isValid: Bool, source: PositionSource = .accessibility) {
            self.rect = rect
            self.isValid = isValid
            self.source = source
        }
    }

    static let shared = CursorTracker()

    /// 记录最后一次鼠标点击位置
    private var lastClickPosition: CGPoint?
    private var lastClickTime: Date?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private init() {}

    // MARK: - 鼠标点击监听

    /// 开始监听鼠标点击事件
    func startMonitoringClicks() {
        guard eventTap == nil else {
            NSLog("[CursorTracker] 鼠标监听已在运行")
            return
        }

        // 使用 NSEvent 全局监听器作为替代方案（更可靠）
        setupNSEventMonitor()
    }

    /// 使用 NSEvent 全局监听器（比 CGEvent tap 更可靠）
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private func setupNSEventMonitor() {
        // 全局监听器：监听其他应用的鼠标点击
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.recordClickPosition(event.locationInWindow, screenLocation: NSEvent.mouseLocation)
        }

        // 本地监听器：监听本应用的鼠标点击
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.recordClickPosition(event.locationInWindow, screenLocation: NSEvent.mouseLocation)
            return event
        }

        if globalMonitor != nil {
            NSLog("[CursorTracker] 鼠标点击监听已启动 (NSEvent)")
        } else {
            NSLog("[CursorTracker] 无法创建全局鼠标监听器，请检查辅助功能权限")
        }
    }

    private func recordClickPosition(_ windowLocation: CGPoint, screenLocation: CGPoint) {
        // NSEvent.mouseLocation 返回的是 AppKit 坐标系（左下角为原点）
        lastClickPosition = screenLocation
        lastClickTime = Date()
        NSLog("[CursorTracker] 记录鼠标点击位置: \(screenLocation)")
    }

    /// 停止监听鼠标点击事件
    func stopMonitoringClicks() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            eventTap = nil
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        NSLog("[CursorTracker] 鼠标点击监听已停止")
    }

    private func handleMouseClick(_ event: CGEvent) {
        lastClickPosition = event.location
        lastClickTime = Date()
        NSLog("[CursorTracker] 记录鼠标点击位置 (CGEvent): \(event.location)")
    }

    // MARK: - 光标位置获取

    /// 获取当前输入光标的屏幕位置
    /// - Returns: 光标位置信息，如果无法获取则返回 invalid
    func getCurrentCursorPosition() -> CursorPosition {
        // 获取系统级 Accessibility 元素
        let systemWide = AXUIElementCreateSystemWide()

        // 获取当前焦点元素
        var focusedElement: AnyObject?
        let focusResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard focusResult == .success,
              let element = focusedElement else {
            NSLog("[CursorTracker] 无法获取焦点元素，尝试鼠标点击回退")
            return getMouseClickFallback()
        }

        let axElement = element as! AXUIElement

        // 尝试方法1：通过选中文本范围获取光标位置
        if let position = getCursorPositionFromSelectedRange(axElement) {
            return position
        }

        // 尝试方法2：通过插入点获取光标位置
        if let position = getCursorPositionFromInsertionPoint(axElement) {
            return position
        }

        // 尝试方法3：获取焦点元素自身的位置（带估算优化）
        if let position = getElementPosition(axElement) {
            return position
        }

        // 尝试方法4：回退到鼠标点击位置
        NSLog("[CursorTracker] Accessibility 方法均失败，使用鼠标点击回退")
        return getMouseClickFallback()
    }

    /// 获取鼠标点击位置作为回退
    private func getMouseClickFallback() -> CursorPosition {
        // 检查是否有有效的点击位置（10秒内）
        if let clickPos = lastClickPosition,
           let clickTime = lastClickTime,
           Date().timeIntervalSince(clickTime) < 10.0 {

            // NSEvent.mouseLocation 已经是 AppKit 坐标系（左下角为原点）
            let cursorRect = CGRect(
                x: clickPos.x,
                y: clickPos.y - 10, // 稍微向下偏移，让悬浮窗显示在点击位置上方
                width: 2,
                height: 20
            )
            NSLog("[CursorTracker] 使用鼠标点击位置: \(cursorRect)")
            return CursorPosition(rect: cursorRect, isValid: true, source: .mouseClick)
        }

        NSLog("[CursorTracker] 无有效的鼠标点击位置")
        return .invalid
    }

    /// 方法1：通过选中文本范围获取光标位置
    private func getCursorPositionFromSelectedRange(_ element: AXUIElement) -> CursorPosition? {
        // 获取选中文本范围
        var selectedRange: AnyObject?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRange
        )

        guard rangeResult == .success,
              let range = selectedRange else {
            return nil
        }

        // 通过范围获取屏幕边界
        var bounds: AnyObject?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            range,
            &bounds
        )

        guard boundsResult == .success,
              let boundsValue = bounds else {
            return nil
        }

        // 转换为 CGRect
        var rect = CGRect.zero
        if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) {
            // Accessibility API 返回的是屏幕坐标（左上角为原点）
            // 需要转换为 AppKit 坐标系（左下角为原点）
            if let screen = NSScreen.main {
                let flippedY = screen.frame.height - rect.origin.y - rect.height
                rect.origin.y = flippedY
            }
            NSLog("[CursorTracker] 通过 SelectedTextRange 获取位置: \(rect)")
            return CursorPosition(rect: rect, isValid: true, source: .accessibility)
        }

        return nil
    }

    /// 方法2：通过插入点获取光标位置
    private func getCursorPositionFromInsertionPoint(_ element: AXUIElement) -> CursorPosition? {
        // 某些应用支持 AXInsertionPointLineNumber
        var insertionPoint: AnyObject?
        let pointResult = AXUIElementCopyAttributeValue(
            element,
            "AXInsertionPointLineNumber" as CFString,
            &insertionPoint
        )

        // 如果有插入点，尝试获取可见字符范围的边界
        if pointResult == .success {
            var visibleRange: AnyObject?
            let visibleResult = AXUIElementCopyAttributeValue(
                element,
                kAXVisibleCharacterRangeAttribute as CFString,
                &visibleRange
            )

            if visibleResult == .success, let range = visibleRange {
                var bounds: AnyObject?
                let boundsResult = AXUIElementCopyParameterizedAttributeValue(
                    element,
                    kAXBoundsForRangeParameterizedAttribute as CFString,
                    range,
                    &bounds
                )

                if boundsResult == .success, let boundsValue = bounds {
                    var rect = CGRect.zero
                    if AXValueGetValue(boundsValue as! AXValue, .cgRect, &rect) {
                        if let screen = NSScreen.main {
                            let flippedY = screen.frame.height - rect.origin.y - rect.height
                            rect.origin.y = flippedY
                        }
                        NSLog("[CursorTracker] 通过 InsertionPoint 获取位置: \(rect)")
                        return CursorPosition(rect: rect, isValid: true, source: .accessibility)
                    }
                }
            }
        }

        return nil
    }

    /// 方法3：获取焦点元素自身的位置
    /// 对于大元素，估算光标在左下角附近
    private func getElementPosition(_ element: AXUIElement) -> CursorPosition? {
        var position: AnyObject?
        var size: AnyObject?

        let posResult = AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &position
        )

        let sizeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSizeAttribute as CFString,
            &size
        )

        guard posResult == .success,
              sizeResult == .success,
              let posValue = position,
              let sizeValue = size else {
            return nil
        }

        var point = CGPoint.zero
        var elementSize = CGSize.zero

        if AXValueGetValue(posValue as! AXValue, .cgPoint, &point),
           AXValueGetValue(sizeValue as! AXValue, .cgSize, &elementSize) {

            // 转换坐标系
            if let screen = NSScreen.main {
                let flippedY = screen.frame.height - point.y - elementSize.height
                point.y = flippedY
            }

            // 如果元素较大（宽度或高度超过 100pt），使用左下角作为估算位置
            if elementSize.width > 100 || elementSize.height > 100 {
                // 估算光标在区域左侧，稍微偏移
                let estimatedCursor = CGRect(
                    x: point.x + 20,  // 稍微偏移，避免贴边
                    y: point.y,        // 使用元素底部
                    width: 2,
                    height: 20
                )
                NSLog("[CursorTracker] 元素较大 (\(elementSize.width)x\(elementSize.height))，估算光标位置: \(estimatedCursor)")
                return CursorPosition(rect: estimatedCursor, isValid: true, source: .elementEstimate)
            }

            let rect = CGRect(origin: point, size: elementSize)
            NSLog("[CursorTracker] 通过元素位置获取: \(rect)")
            return CursorPosition(rect: rect, isValid: true, source: .accessibility)
        }

        return nil
    }
}
