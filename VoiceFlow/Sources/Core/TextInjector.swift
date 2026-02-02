import AppKit
import Carbon

final class TextInjector {
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

        // Clipboard-based injection for Korean text compatibility
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)
        NSLog("[TextInjector] 📋 Previous clipboard saved")

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        NSLog("[TextInjector] 📋 Text copied to clipboard: \(text)")

        simulatePaste()
        NSLog("[TextInjector] ⌨️ Paste command sent (Cmd+V)")

        // Restore previous clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pasteboard.clearContents()
            if let previous = previousContents {
                pasteboard.setString(previous, forType: .string)
            }
            NSLog("[TextInjector] 📋 Previous clipboard restored")
        }

        NSLog("[TextInjector] ✅ Injection completed")
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
}
