import AppKit
import Carbon

final class TextInjector {
    private let maxPasteWaitTime: TimeInterval = 0.5  // 最大等待粘贴完成时间
    private let pasteCheckInterval: TimeInterval = 0.01  // 检查间隔

    func inject(text: String) {
        NSLog("[TextInjector] 🚀 Starting injection for text: \(text.prefix(50))")
        NSLog("[TextInjector] 📊 Full text length: \(text.count) characters")

        // Check Accessibility permissions
        let trusted = AXIsProcessTrusted()
        NSLog("[TextInjector] ✅ Accessibility permission status: \(trusted)")

        if !trusted {
            NSLog("[TextInjector] ❌❌❌ CRITICAL: No Accessibility permission! Text injection WILL FAIL.")
            NSLog("[TextInjector] 🔧 FIX: System Settings → Privacy & Security → Accessibility → Add VoiceFlow")

            // Show alert to user
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "VoiceFlow需要辅助功能权限才能注入文本。\n\n请前往：\n系统设置 → 隐私与安全性 → 辅助功能\n\n添加VoiceFlow并开启权限后，重启应用。"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "知道了")
                alert.runModal()
            }
            return  // Don't attempt injection without permission
        }

        // 注入前确认焦点应用未切换
        let frontmostApp = NSWorkspace.shared.frontmostApplication
        NSLog("[TextInjector] 📱 Target app: \(frontmostApp?.localizedName ?? "Unknown")")

        // Process text through enabled plugins
        let processedText = PluginManager.shared.processText(text)

        // Clipboard-based injection for Korean text compatibility
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount
        NSLog("[TextInjector] 📋 Previous clipboard saved (changeCount: \(previousChangeCount))")

        pasteboard.clearContents()
        pasteboard.setString(processedText, forType: .string)

        // 记录注入时的 changeCount，用于后续 polish_update 判断
        UserDefaults.standard.set(pasteboard.changeCount, forKey: "lastInjectedChangeCount")
        NSLog("[TextInjector] 📋 Text copied to clipboard: \(processedText)")

        simulatePaste()
        NSLog("[TextInjector] ⌨️ Paste command sent (Cmd+V)")

        // 动态检测粘贴完成：轮询 changeCount 变化
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let startTime = Date()
            let expectedChangeCount = pasteboard.changeCount

            // 等待粘贴完成（changeCount 变化或超时）
            while Date().timeIntervalSince(startTime) < self.maxPasteWaitTime {
                Thread.sleep(forTimeInterval: self.pasteCheckInterval)

                // 如果 changeCount 变化，说明粘贴可能已完成
                if pasteboard.changeCount != expectedChangeCount {
                    NSLog("[TextInjector] 📋 Paste detected (changeCount changed)")
                    break
                }
            }

            // 恢复之前的剪贴板内容
            DispatchQueue.main.async {
                pasteboard.clearContents()
                if let previous = previousContents {
                    pasteboard.setString(previous, forType: .string)
                }
                NSLog("[TextInjector] 📋 Previous clipboard restored (waited \(String(format: "%.0f", Date().timeIntervalSince(startTime) * 1000))ms)")
            }
        }

        NSLog("[TextInjector] ✅ Injection initiated")
    }

    private func simulatePaste() {
        // Small delay to ensure target app is ready to receive paste
        usleep(50000)  // 50ms delay

        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
            NSLog("[TextInjector] ❌ Failed to create keyDown event!")
            return
        }
        keyDown.flags = .maskCommand
        NSLog("[TextInjector] ⌨️ Created Cmd+V keyDown event")

        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            NSLog("[TextInjector] ❌ Failed to create keyUp event!")
            return
        }
        keyUp.flags = .maskCommand
        NSLog("[TextInjector] ⌨️ Created Cmd+V keyUp event")

        keyDown.post(tap: .cgSessionEventTap)
        NSLog("[TextInjector] 📤 Posted keyDown event")

        usleep(10000)  // 10ms between key down and up

        keyUp.post(tap: .cgSessionEventTap)
        NSLog("[TextInjector] 📤 Posted keyUp event")
    }

    /// 替换已输入的文本（用于 LLM 纠错后更新）
    /// 通过模拟 Cmd+A 全选 + Cmd+V 粘贴实现替换
    func replaceLastInjectedText(with newText: String) {
        NSLog("[TextInjector] 🔄 Replacing with LLM corrected text: \(newText.prefix(50))")

        // Check Accessibility permissions
        guard AXIsProcessTrusted() else {
            NSLog("[TextInjector] ❌ No Accessibility permission for replacement")
            return
        }

        // Process text through enabled plugins
        let processedText = PluginManager.shared.processText(newText)

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        // Set new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(processedText, forType: .string)
        UserDefaults.standard.set(pasteboard.changeCount, forKey: "lastInjectedChangeCount")

        // Simulate Cmd+A (Select All) then Cmd+V (Paste)
        simulateSelectAllAndPaste()

        // Restore clipboard after delay
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + maxPasteWaitTime) {
            DispatchQueue.main.async {
                pasteboard.clearContents()
                if let previous = previousContents {
                    pasteboard.setString(previous, forType: .string)
                }
                NSLog("[TextInjector] 📋 Clipboard restored after replacement")
            }
        }

        NSLog("[TextInjector] ✅ Replacement initiated")
    }

    private func simulateSelectAllAndPaste() {
        usleep(50000)  // 50ms delay

        let source = CGEventSource(stateID: .hidSystemState)

        // Cmd+A (Select All)
        if let keyDownA = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: true),
           let keyUpA = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: false) {
            keyDownA.flags = .maskCommand
            keyUpA.flags = .maskCommand
            keyDownA.post(tap: .cgSessionEventTap)
            usleep(10000)
            keyUpA.post(tap: .cgSessionEventTap)
            NSLog("[TextInjector] ⌨️ Cmd+A sent (Select All)")
        }

        usleep(50000)  // 50ms delay between select and paste

        // Cmd+V (Paste)
        if let keyDownV = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
           let keyUpV = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) {
            keyDownV.flags = .maskCommand
            keyUpV.flags = .maskCommand
            keyDownV.post(tap: .cgSessionEventTap)
            usleep(10000)
            keyUpV.post(tap: .cgSessionEventTap)
            NSLog("[TextInjector] ⌨️ Cmd+V sent (Paste)")
        }
    }
}
