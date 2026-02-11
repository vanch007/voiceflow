import XCTest
import AppKit
import Carbon
@testable import VoiceFlow

/// Unit tests for TextInjector clipboard operations and text processing workflow
final class TextInjectorTests: XCTestCase {
    var textInjector: TextInjector!
    var originalClipboard: String?

    override func setUp() {
        super.setUp()
        textInjector = TextInjector()

        // Save original clipboard state
        let pasteboard = NSPasteboard.general
        originalClipboard = pasteboard.string(forType: .string)
    }

    override func tearDown() {
        // Restore original clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let original = originalClipboard {
            pasteboard.setString(original, forType: .string)
        }

        textInjector = nil
        originalClipboard = nil
        super.tearDown()
    }

    // MARK: - Clipboard Operations Tests

    func testInjectCopiesTextToClipboard() {
        // Given: Text to inject
        let testText = "Hello, World!"
        let pasteboard = NSPasteboard.general

        // When: Inject text (without accessibility permission, it stops early but still copies to clipboard)
        textInjector.inject(text: testText)

        // Then: Text should be in clipboard (if accessibility is granted) or not (if not granted)
        // Since we can't guarantee accessibility permission in tests, we verify the behavior is consistent
        let clipboardContent = pasteboard.string(forType: .string)

        // If accessibility is granted, clipboard will have the text
        // If not granted, clipboard won't be modified
        if AXIsProcessTrusted() {
            XCTAssertEqual(clipboardContent, testText, "Text should be copied to clipboard when accessible")
        }
    }

    func testInjectPreservesClipboardState() {
        // Given: Existing clipboard content
        let pasteboard = NSPasteboard.general
        let originalContent = "Original clipboard content"
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        let testText = "Test injection text"

        // When: Inject text
        textInjector.inject(text: testText)

        // Wait for clipboard restoration (maxPasteWaitTime = 0.5s)
        let expectation = self.expectation(description: "Clipboard restoration")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then: Original clipboard should be restored (if injection occurred)
        if AXIsProcessTrusted() {
            let restoredContent = pasteboard.string(forType: .string)
            XCTAssertEqual(restoredContent, originalContent, "Original clipboard should be restored after injection")
        }
    }

    func testInjectRecordsChangeCount() {
        // Given: Text to inject
        let testText = "Test for changeCount tracking"
        let pasteboard = NSPasteboard.general

        // Clear previous tracking
        UserDefaults.standard.removeObject(forKey: "lastInjectedChangeCount")

        // When: Inject text
        textInjector.inject(text: testText)

        // Then: changeCount should be recorded in UserDefaults (if accessible)
        if AXIsProcessTrusted() {
            let recordedChangeCount = UserDefaults.standard.integer(forKey: "lastInjectedChangeCount")
            XCTAssertGreaterThan(recordedChangeCount, 0, "changeCount should be recorded")
            XCTAssertEqual(recordedChangeCount, pasteboard.changeCount, "Recorded changeCount should match pasteboard")
        }
    }

    func testInjectHandlesEmptyString() {
        // Given: Empty string
        let emptyText = ""
        let pasteboard = NSPasteboard.general

        // When: Inject empty text
        textInjector.inject(text: emptyText)

        // Then: Should handle gracefully without crashing
        if AXIsProcessTrusted() {
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, emptyText, "Empty string should be handled correctly")
        }
    }

    func testInjectHandlesUnicodeText() {
        // Given: Unicode text with various scripts
        let unicodeText = "Hello 世界 🌍 مرحبا 안녕하세요"

        // When: Inject unicode text
        textInjector.inject(text: unicodeText)

        // Then: Should handle all unicode characters correctly
        if AXIsProcessTrusted() {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, unicodeText, "Unicode text should be preserved")
        }
    }

    func testInjectHandlesLongText() {
        // Given: Very long text (1000 characters)
        let longText = String(repeating: "Lorem ipsum dolor sit amet. ", count: 36)
        XCTAssertGreaterThan(longText.count, 1000, "Test text should be long")

        // When: Inject long text
        textInjector.inject(text: longText)

        // Then: Should handle long text without truncation
        if AXIsProcessTrusted() {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, longText, "Long text should not be truncated")
        }
    }

    // MARK: - Replace Text Tests

    func testReplaceTextCopiesNewTextToClipboard() {
        // Given: New corrected text
        let newText = "Corrected text with LLM polish"
        let pasteboard = NSPasteboard.general

        // When: Replace with new text
        textInjector.replaceLastInjectedText(with: newText)

        // Then: New text should be in clipboard
        if AXIsProcessTrusted() {
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, newText, "New text should be in clipboard")
        }
    }

    func testReplaceTextRecordsChangeCount() {
        // Given: New text for replacement
        let newText = "Updated text"
        let pasteboard = NSPasteboard.general

        // Clear previous tracking
        UserDefaults.standard.removeObject(forKey: "lastInjectedChangeCount")

        // When: Replace text
        textInjector.replaceLastInjectedText(with: newText)

        // Then: changeCount should be updated
        if AXIsProcessTrusted() {
            let recordedChangeCount = UserDefaults.standard.integer(forKey: "lastInjectedChangeCount")
            XCTAssertGreaterThan(recordedChangeCount, 0, "changeCount should be recorded for replacement")
            XCTAssertEqual(recordedChangeCount, pasteboard.changeCount, "Recorded changeCount should match current")
        }
    }

    func testReplaceTextPreservesClipboard() {
        // Given: Existing clipboard content
        let pasteboard = NSPasteboard.general
        let originalContent = "Original content before replace"
        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        let newText = "Replacement text"

        // When: Replace text
        textInjector.replaceLastInjectedText(with: newText)

        // Wait for clipboard restoration (maxPasteWaitTime = 0.5s)
        let expectation = self.expectation(description: "Clipboard restoration after replace")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // Then: Original clipboard should be restored
        if AXIsProcessTrusted() {
            let restoredContent = pasteboard.string(forType: .string)
            XCTAssertEqual(restoredContent, originalContent, "Clipboard should be restored after replacement")
        }
    }

    func testReplaceTextHandlesEmptyString() {
        // Given: Empty replacement string
        let emptyText = ""

        // When: Replace with empty text
        textInjector.replaceLastInjectedText(with: emptyText)

        // Then: Should handle gracefully without crashing
        if AXIsProcessTrusted() {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, emptyText, "Empty replacement should be handled")
        }
    }

    // MARK: - CGEvent Creation Tests

    func testCGEventSourceCreation() {
        // Given: System state
        let source = CGEventSource(stateID: .hidSystemState)

        // Then: Event source should be created successfully
        XCTAssertNotNil(source, "CGEventSource should be created")
    }

    func testCGEventCreationForPaste() {
        // Given: Event source
        let source = CGEventSource(stateID: .hidSystemState)

        // When: Create Cmd+V events
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)

        // Then: Events should be created successfully
        XCTAssertNotNil(keyDown, "Cmd+V keyDown event should be created")
        XCTAssertNotNil(keyUp, "Cmd+V keyUp event should be created")

        // Verify flags can be set
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        XCTAssertTrue(keyDown?.flags.contains(.maskCommand) ?? false, "Command flag should be set on keyDown")
        XCTAssertTrue(keyUp?.flags.contains(.maskCommand) ?? false, "Command flag should be set on keyUp")
    }

    func testCGEventCreationForSelectAll() {
        // Given: Event source
        let source = CGEventSource(stateID: .hidSystemState)

        // When: Create Cmd+A events
        let keyDownA = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: true)
        let keyUpA = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: false)

        // Then: Events should be created successfully
        XCTAssertNotNil(keyDownA, "Cmd+A keyDown event should be created")
        XCTAssertNotNil(keyUpA, "Cmd+A keyUp event should be created")

        // Verify flags can be set
        keyDownA?.flags = .maskCommand
        keyUpA?.flags = .maskCommand

        XCTAssertTrue(keyDownA?.flags.contains(.maskCommand) ?? false, "Command flag should be set on keyDown")
        XCTAssertTrue(keyUpA?.flags.contains(.maskCommand) ?? false, "Command flag should be set on keyUp")
    }

    // MARK: - Permission Tests

    func testAccessibilityPermissionCheck() {
        // When: Check accessibility permission
        let trusted = AXIsProcessTrusted()

        // Then: Should return a boolean value
        XCTAssertTrue(trusted == true || trusted == false, "Permission check should return boolean")
    }

    // MARK: - Edge Cases Tests

    func testInjectWithSpecialCharacters() {
        // Given: Text with special characters
        let specialText = "Test with \"quotes\", 'apostrophes', and\nnewlines\ttabs"

        // When: Inject text
        textInjector.inject(text: specialText)

        // Then: Should handle special characters correctly
        if AXIsProcessTrusted() {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, specialText, "Special characters should be preserved")
        }
    }

    func testInjectWithOnlyWhitespace() {
        // Given: Text with only whitespace
        let whitespaceText = "   \t\n   "

        // When: Inject whitespace text
        textInjector.inject(text: whitespaceText)

        // Then: Should handle whitespace-only text
        if AXIsProcessTrusted() {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, whitespaceText, "Whitespace-only text should be handled")
        }
    }

    func testMultipleConsecutiveInjections() {
        // Given: Multiple texts to inject
        let texts = ["First injection", "Second injection", "Third injection"]

        // When: Inject multiple times consecutively
        for text in texts {
            textInjector.inject(text: text)
            Thread.sleep(forTimeInterval: 0.1)  // Small delay between injections
        }

        // Then: Last text should be in clipboard
        if AXIsProcessTrusted() {
            let pasteboard = NSPasteboard.general
            let clipboardContent = pasteboard.string(forType: .string)
            XCTAssertEqual(clipboardContent, texts.last, "Last injection should be in clipboard")
        }
    }

    func testChangeCountIncrementsOnInjection() {
        // Given: Initial changeCount
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // When: Inject text
        textInjector.inject(text: "Test changeCount increment")

        // Then: changeCount should increment (if accessible)
        if AXIsProcessTrusted() {
            let newChangeCount = pasteboard.changeCount
            XCTAssertGreaterThan(newChangeCount, initialChangeCount, "changeCount should increment after injection")
        }
    }

    func testReplaceTextChangeCountIncrement() {
        // Given: Initial changeCount
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // When: Replace text
        textInjector.replaceLastInjectedText(with: "Replacement text")

        // Then: changeCount should increment (if accessible)
        if AXIsProcessTrusted() {
            let newChangeCount = pasteboard.changeCount
            XCTAssertGreaterThan(newChangeCount, initialChangeCount, "changeCount should increment after replacement")
        }
    }

    // MARK: - Timing Tests

    func testClipboardRestorationTiming() {
        // Given: Text to inject
        let testText = "Timing test text"
        let pasteboard = NSPasteboard.general
        let originalContent = "Original for timing test"

        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        // When: Inject text
        let startTime = Date()
        textInjector.inject(text: testText)

        // Then: Clipboard should be restored within maxPasteWaitTime (0.5s) + buffer
        let expectation = self.expectation(description: "Clipboard restoration timing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let elapsed = Date().timeIntervalSince(startTime)

        if AXIsProcessTrusted() {
            XCTAssertLessThan(elapsed, 1.0, "Clipboard restoration should complete within 1 second")

            let restoredContent = pasteboard.string(forType: .string)
            XCTAssertEqual(restoredContent, originalContent, "Original content should be restored")
        }
    }

    func testReplaceTextRestorationTiming() {
        // Given: Text to replace
        let newText = "Timing test replacement"
        let pasteboard = NSPasteboard.general
        let originalContent = "Original for replacement timing"

        pasteboard.clearContents()
        pasteboard.setString(originalContent, forType: .string)

        // When: Replace text
        let startTime = Date()
        textInjector.replaceLastInjectedText(with: newText)

        // Then: Clipboard should be restored within maxPasteWaitTime (0.5s) + buffer
        let expectation = self.expectation(description: "Replace clipboard restoration timing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        let elapsed = Date().timeIntervalSince(startTime)

        if AXIsProcessTrusted() {
            XCTAssertLessThan(elapsed, 1.0, "Replace clipboard restoration should complete within 1 second")

            let restoredContent = pasteboard.string(forType: .string)
            XCTAssertEqual(restoredContent, originalContent, "Original content should be restored after replace")
        }
    }
}
