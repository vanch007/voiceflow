import AppKit
import Carbon

final class TextInjector {
    func inject(text: String) {
        // Process text through enabled plugins
        let processedText = PluginManager.shared.processText(text)

        // Clipboard-based injection for Korean text compatibility
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(processedText, forType: .string)

        simulatePaste()

        // Restore previous clipboard after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pasteboard.clearContents()
            if let previous = previousContents {
                pasteboard.setString(previous, forType: .string)
            }
        }

        NSLog("[TextInjector] Injected text: \(processedText.prefix(50))")
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
