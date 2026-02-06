import AppKit
import ApplicationServices

/// 光标位置追踪器 - 通过 Accessibility API 获取当前输入光标的屏幕位置
final class CursorTracker {

    struct CursorPosition {
        let rect: CGRect           // 光标屏幕坐标
        let isValid: Bool          // 是否成功获取
        let source: PositionSource // 位置来源

        enum PositionSource {
            case accessibility     // 从 Accessibility API 获取
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

    private init() {}

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
            NSLog("[CursorTracker] 无法获取焦点元素")
            return .invalid
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

        NSLog("[CursorTracker] Accessibility 方法均失败")
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
