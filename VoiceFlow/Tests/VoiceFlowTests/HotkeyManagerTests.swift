import XCTest
@testable import VoiceFlow

/// Unit tests for HotkeyManager configuration and conflict detection
final class HotkeyManagerTests: XCTestCase {
    var hotkeyManager: HotkeyManager!

    override func setUp() {
        super.setUp()
        hotkeyManager = HotkeyManager()

        // Reset to default config before each test
        hotkeyManager.resetToDefault()
    }

    override func tearDown() {
        hotkeyManager.resetToDefault()
        hotkeyManager = nil
        super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        // When: Get default config
        let config = hotkeyManager.getCurrentConfig()

        // Then: Should match HotkeyConfig.default
        XCTAssertEqual(config.triggerType, HotkeyConfig.default.triggerType, "Default trigger type should match")
        XCTAssertEqual(config.keyCode, HotkeyConfig.default.keyCode, "Default key code should match")
        XCTAssertEqual(config.interval, HotkeyConfig.default.interval, "Default interval should match")
    }

    func testUpdateConfiguration() {
        // Given: A new configuration
        let newConfig = HotkeyConfig(
            triggerType: .doubleTap,
            keyCode: 58, // Left Option
            modifiers: [],
            interval: 0.3
        )

        // When: Update config
        hotkeyManager.updateConfig(newConfig)

        // Then: Config should be updated
        let currentConfig = hotkeyManager.getCurrentConfig()
        XCTAssertEqual(currentConfig.triggerType, .doubleTap, "Trigger type should be updated")
        XCTAssertEqual(currentConfig.keyCode, 58, "Key code should be updated")
        XCTAssertEqual(currentConfig.interval, 0.3, "Interval should be updated")
    }

    func testSaveAndLoadConfiguration() {
        // Given: A custom configuration
        let customConfig = HotkeyConfig(
            triggerType: .longPress,
            keyCode: 59, // Left Control
            modifiers: [],
            interval: 0.5
        )

        // When: Save config
        hotkeyManager.saveConfig(customConfig)

        // Then: Create new manager and verify it loads the saved config
        let newManager = HotkeyManager()
        let loadedConfig = newManager.getCurrentConfig()

        XCTAssertEqual(loadedConfig.triggerType, .longPress, "Loaded trigger type should match saved")
        XCTAssertEqual(loadedConfig.keyCode, 59, "Loaded key code should match saved")
        XCTAssertEqual(loadedConfig.interval, 0.5, "Loaded interval should match saved")

        // Cleanup
        newManager.resetToDefault()
    }

    func testResetToDefault() {
        // Given: A custom configuration
        let customConfig = HotkeyConfig(
            triggerType: .freeSpeak,
            keyCode: 61, // Right Option
            modifiers: [],
            interval: 0.4
        )
        hotkeyManager.saveConfig(customConfig)

        // When: Reset to default
        hotkeyManager.resetToDefault()

        // Then: Config should be default
        let currentConfig = hotkeyManager.getCurrentConfig()
        XCTAssertEqual(currentConfig.triggerType, HotkeyConfig.default.triggerType, "Should reset to default trigger type")
        XCTAssertEqual(currentConfig.keyCode, HotkeyConfig.default.keyCode, "Should reset to default key code")
    }

    func testConfigurationNotification() {
        // Given: Expectation for notification
        let expectation = expectation(forNotification: .hotkeyConfigDidChange, object: nil)

        let newConfig = HotkeyConfig(
            triggerType: .doubleTap,
            keyCode: 58,
            modifiers: [],
            interval: 0.3
        )

        // When: Post config change notification
        NotificationCenter.default.post(
            name: .hotkeyConfigDidChange,
            object: nil,
            userInfo: ["config": newConfig]
        )

        // Then: Notification should be received
        wait(for: [expectation], timeout: 1.0)

        // Verify config was updated
        let currentConfig = hotkeyManager.getCurrentConfig()
        XCTAssertEqual(currentConfig.triggerType, .doubleTap, "Config should be updated from notification")
    }

    // MARK: - Enable/Disable Tests

    func testEnableDisableState() {
        // When: Disable hotkey manager
        hotkeyManager.disable()

        // Then: Should be disabled (we can't directly test isEnabled since it's private,
        // but we verify no crashes occur)
        XCTAssertNotNil(hotkeyManager, "Manager should still exist when disabled")

        // When: Re-enable
        hotkeyManager.enable()

        // Then: Should be enabled
        XCTAssertNotNil(hotkeyManager, "Manager should exist when enabled")
    }

    // MARK: - Callback Registration Tests

    func testLongPressCallbackRegistration() {
        // Given: A callback expectation
        let expectation = XCTestExpectation(description: "Long press callback should be called")

        // When: Register callback
        hotkeyManager.onLongPress = {
            expectation.fulfill()
        }

        // Then: Callback should be registered
        XCTAssertNotNil(hotkeyManager.onLongPress, "Long press callback should be registered")

        // Trigger callback manually to verify it works
        hotkeyManager.onLongPress?()

        wait(for: [expectation], timeout: 1.0)
    }

    func testLongPressEndCallbackRegistration() {
        // Given: A callback expectation
        let expectation = XCTestExpectation(description: "Long press end callback should be called")

        // When: Register callback
        hotkeyManager.onLongPressEnd = {
            expectation.fulfill()
        }

        // Then: Callback should be registered
        XCTAssertNotNil(hotkeyManager.onLongPressEnd, "Long press end callback should be registered")

        // Trigger callback manually to verify it works
        hotkeyManager.onLongPressEnd?()

        wait(for: [expectation], timeout: 1.0)
    }

    func testToggleRecordingCallbackRegistration() {
        // Given: A callback expectation
        let expectation = XCTestExpectation(description: "Toggle recording callback should be called")

        // When: Register callback
        hotkeyManager.onToggleRecording = {
            expectation.fulfill()
        }

        // Then: Callback should be registered
        XCTAssertNotNil(hotkeyManager.onToggleRecording, "Toggle recording callback should be registered")

        // Trigger callback manually to verify it works
        hotkeyManager.onToggleRecording?()

        wait(for: [expectation], timeout: 1.0)
    }

    func testSystemAudioDoubleTapCallbackRegistration() {
        // Given: A callback expectation
        let expectation = XCTestExpectation(description: "System audio double-tap callback should be called")

        // When: Register callback
        hotkeyManager.onSystemAudioDoubleTap = {
            expectation.fulfill()
        }

        // Then: Callback should be registered
        XCTAssertNotNil(hotkeyManager.onSystemAudioDoubleTap, "System audio double-tap callback should be registered")

        // Trigger callback manually to verify it works
        hotkeyManager.onSystemAudioDoubleTap?()

        wait(for: [expectation], timeout: 1.0)
    }

    func testMultipleCallbackRegistration() {
        // Given: Multiple callback expectations
        let longPressExpectation = XCTestExpectation(description: "Long press callback")
        let longPressEndExpectation = XCTestExpectation(description: "Long press end callback")
        let toggleExpectation = XCTestExpectation(description: "Toggle recording callback")
        let systemAudioExpectation = XCTestExpectation(description: "System audio callback")

        // When: Register all callbacks
        hotkeyManager.onLongPress = { longPressExpectation.fulfill() }
        hotkeyManager.onLongPressEnd = { longPressEndExpectation.fulfill() }
        hotkeyManager.onToggleRecording = { toggleExpectation.fulfill() }
        hotkeyManager.onSystemAudioDoubleTap = { systemAudioExpectation.fulfill() }

        // Then: All callbacks should be registered
        XCTAssertNotNil(hotkeyManager.onLongPress, "Long press callback should be registered")
        XCTAssertNotNil(hotkeyManager.onLongPressEnd, "Long press end callback should be registered")
        XCTAssertNotNil(hotkeyManager.onToggleRecording, "Toggle recording callback should be registered")
        XCTAssertNotNil(hotkeyManager.onSystemAudioDoubleTap, "System audio callback should be registered")

        // Trigger all callbacks
        hotkeyManager.onLongPress?()
        hotkeyManager.onLongPressEnd?()
        hotkeyManager.onToggleRecording?()
        hotkeyManager.onSystemAudioDoubleTap?()

        wait(for: [longPressExpectation, longPressEndExpectation, toggleExpectation, systemAudioExpectation], timeout: 1.0)
    }

    func testCallbackExecutionWithState() {
        // Given: Callback with state tracking
        var callbackExecuted = false

        // When: Register callback that modifies state
        hotkeyManager.onLongPress = {
            callbackExecuted = true
        }

        // Then: State should not be modified until callback is executed
        XCTAssertFalse(callbackExecuted, "Callback should not execute on registration")

        // When: Execute callback
        hotkeyManager.onLongPress?()

        // Then: State should be modified
        XCTAssertTrue(callbackExecuted, "Callback should execute when triggered")
    }

    func testCallbackReplacement() {
        // Given: Initial callback
        var firstCallbackExecuted = false
        var secondCallbackExecuted = false

        hotkeyManager.onLongPress = {
            firstCallbackExecuted = true
        }

        // When: Replace with new callback
        hotkeyManager.onLongPress = {
            secondCallbackExecuted = true
        }

        // Then: Only new callback should execute
        hotkeyManager.onLongPress?()

        XCTAssertFalse(firstCallbackExecuted, "First callback should not execute after replacement")
        XCTAssertTrue(secondCallbackExecuted, "Second callback should execute")
    }

    func testCallbackUnregistration() {
        // Given: Registered callback
        var callbackExecuted = false

        hotkeyManager.onLongPress = {
            callbackExecuted = true
        }

        // When: Unregister callback
        hotkeyManager.onLongPress = nil

        // Then: Callback should be nil
        XCTAssertNil(hotkeyManager.onLongPress, "Callback should be unregistered")

        // When: Try to execute nil callback
        hotkeyManager.onLongPress?()

        // Then: No crash and state should not change
        XCTAssertFalse(callbackExecuted, "Nil callback should not execute")
    }

    func testCallbackExecutionCount() {
        // Given: Counter for callback executions
        var executionCount = 0

        hotkeyManager.onToggleRecording = {
            executionCount += 1
        }

        // When: Execute callback multiple times
        hotkeyManager.onToggleRecording?()
        hotkeyManager.onToggleRecording?()
        hotkeyManager.onToggleRecording?()

        // Then: Counter should reflect all executions
        XCTAssertEqual(executionCount, 3, "Callback should execute exactly 3 times")
    }

    func testCallbacksIndependence() {
        // Given: Independent callback states
        var longPressCount = 0
        var toggleCount = 0

        hotkeyManager.onLongPress = { longPressCount += 1 }
        hotkeyManager.onToggleRecording = { toggleCount += 1 }

        // When: Execute callbacks independently
        hotkeyManager.onLongPress?()
        hotkeyManager.onToggleRecording?()
        hotkeyManager.onToggleRecording?()

        // Then: Each should maintain independent state
        XCTAssertEqual(longPressCount, 1, "Long press should execute once")
        XCTAssertEqual(toggleCount, 2, "Toggle should execute twice")
    }

    // MARK: - Conflict Detection Tests

    func testSpotlightConflictDetection() {
        // Given: Cmd + Space configuration (conflicts with Spotlight)
        let spotlightConfig = HotkeyConfig(
            triggerType: .combination,
            keyCode: 49, // Space
            modifiers: [.command],
            interval: 0.3
        )

        hotkeyManager.updateConfig(spotlightConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should detect Spotlight conflict
        XCTAssertGreaterThan(conflicts.count, 0, "Should detect at least one conflict")

        let hasSpotlightConflict = conflicts.contains { conflict in
            conflict.conflictingApp == "Spotlight" && conflict.severity == .critical
        }
        XCTAssertTrue(hasSpotlightConflict, "Should detect Spotlight conflict")
    }

    func testQuitAppConflictDetection() {
        // Given: Cmd + Q configuration (conflicts with quit)
        let quitConfig = HotkeyConfig(
            triggerType: .combination,
            keyCode: 12, // Q
            modifiers: [.command],
            interval: 0.3
        )

        hotkeyManager.updateConfig(quitConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should detect quit conflict
        XCTAssertGreaterThan(conflicts.count, 0, "Should detect at least one conflict")

        let hasQuitConflict = conflicts.contains { conflict in
            conflict.description.contains("Q") && conflict.severity == .critical
        }
        XCTAssertTrue(hasQuitConflict, "Should detect Cmd+Q quit conflict")
    }

    func testEmojiPickerConflictDetection() {
        // Given: Ctrl + Cmd + Space configuration (conflicts with emoji picker)
        let emojiConfig = HotkeyConfig(
            triggerType: .combination,
            keyCode: 49, // Space
            modifiers: [.control, .command],
            interval: 0.3
        )

        hotkeyManager.updateConfig(emojiConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should detect emoji picker conflict
        XCTAssertGreaterThan(conflicts.count, 0, "Should detect at least one conflict")

        let hasEmojiConflict = conflicts.contains { conflict in
            conflict.description.contains("表情") || conflict.description.contains("Space")
        }
        XCTAssertTrue(hasEmojiConflict, "Should detect emoji picker conflict")
    }

    func testForceQuitConflictDetection() {
        // Given: Opt + Cmd + Esc configuration (conflicts with force quit)
        let forceQuitConfig = HotkeyConfig(
            triggerType: .combination,
            keyCode: 53, // Esc
            modifiers: [.option, .command],
            interval: 0.3
        )

        hotkeyManager.updateConfig(forceQuitConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should detect force quit conflict
        XCTAssertGreaterThan(conflicts.count, 0, "Should detect at least one conflict")

        let hasForceQuitConflict = conflicts.contains { conflict in
            conflict.description.contains("强制退出") || conflict.description.contains("Esc")
        }
        XCTAssertTrue(hasForceQuitConflict, "Should detect force quit conflict")
    }

    func testDictationWarningDetection() {
        // Given: Control double-tap configuration (warning for dictation)
        let dictationConfig = HotkeyConfig(
            triggerType: .doubleTap,
            keyCode: 59, // Control
            modifiers: [],
            interval: 0.3
        )

        hotkeyManager.updateConfig(dictationConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should detect dictation warning
        let hasDictationWarning = conflicts.contains { conflict in
            conflict.description.contains("听写") && conflict.severity == .warning
        }
        XCTAssertTrue(hasDictationWarning, "Should warn about dictation conflict")
    }

    func testNoConflictsForSafeConfiguration() {
        // Given: Safe long-press Option configuration
        let safeConfig = HotkeyConfig(
            triggerType: .longPress,
            keyCode: 58, // Left Option
            modifiers: [],
            interval: 0.3
        )

        hotkeyManager.updateConfig(safeConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should not detect any critical conflicts
        let hasCriticalConflicts = conflicts.contains { $0.severity == .critical }
        XCTAssertFalse(hasCriticalConflicts, "Safe long-press config should not have critical conflicts")
    }

    func testMultipleConflictDetection() {
        // Given: Configuration that triggers multiple conflicts
        let multiConflictConfig = HotkeyConfig(
            triggerType: .combination,
            keyCode: 49, // Space
            modifiers: [.command],
            interval: 0.3
        )

        hotkeyManager.updateConfig(multiConflictConfig)

        // When: Check for conflicts
        let conflicts = hotkeyManager.checkForConflicts()

        // Then: Should categorize by severity
        let criticalConflicts = conflicts.filter { $0.severity == .critical }

        XCTAssertGreaterThan(criticalConflicts.count, 0, "Should have critical conflicts")

        // Verify all conflicts have proper structure
        for conflict in conflicts {
            XCTAssertFalse(conflict.description.isEmpty, "Conflict description should not be empty")
            // conflictingApp can be nil for some conflicts
        }
    }

    // MARK: - Configuration Validity Tests

    func testLongPressIntervalValidation() {
        // Given: Long press configs with different intervals
        let shortInterval = HotkeyConfig(
            triggerType: .longPress,
            keyCode: 58,
            modifiers: [],
            interval: 0.1
        )

        let longInterval = HotkeyConfig(
            triggerType: .longPress,
            keyCode: 58,
            modifiers: [],
            interval: 2.0
        )

        // When/Then: Both should be accepted (no validation in current implementation)
        hotkeyManager.updateConfig(shortInterval)
        XCTAssertEqual(hotkeyManager.getCurrentConfig().interval, 0.1, "Should accept short interval")

        hotkeyManager.updateConfig(longInterval)
        XCTAssertEqual(hotkeyManager.getCurrentConfig().interval, 2.0, "Should accept long interval")
    }

    func testDoubleTapIntervalValidation() {
        // Given: Double-tap config with specific interval
        let doubleTapConfig = HotkeyConfig(
            triggerType: .doubleTap,
            keyCode: 58,
            modifiers: [],
            interval: 0.3
        )

        // When: Update config
        hotkeyManager.updateConfig(doubleTapConfig)

        // Then: Interval should be preserved
        let currentConfig = hotkeyManager.getCurrentConfig()
        XCTAssertEqual(currentConfig.interval, 0.3, "Double-tap interval should be preserved")
    }

    func testModifierKeyCodeMapping() {
        // Given: Different modifier key codes
        let testCases: [(UInt16, String)] = [
            (59, "Left Control"),
            (62, "Right Control"),
            (58, "Left Option"),
            (61, "Right Option"),
            (56, "Left Shift"),
            (60, "Right Shift"),
            (55, "Left Command"),
            (54, "Right Command")
        ]

        // When/Then: Each key code should be accepted
        for (keyCode, description) in testCases {
            let config = HotkeyConfig(
                triggerType: .longPress,
                keyCode: keyCode,
                modifiers: [],
                interval: 0.3
            )

            hotkeyManager.updateConfig(config)
            let currentConfig = hotkeyManager.getCurrentConfig()

            XCTAssertEqual(currentConfig.keyCode, keyCode, "\(description) key code should be accepted")
        }
    }

    // MARK: - Display String Tests

    func testConfigurationDisplayStrings() {
        // Given: Various configurations
        let configs: [(HotkeyConfig, String)] = [
            (HotkeyConfig(triggerType: .longPress, keyCode: 58, modifiers: [], interval: 0.3), "should have display string"),
            (HotkeyConfig(triggerType: .doubleTap, keyCode: 59, modifiers: [], interval: 0.3), "should have display string"),
            (HotkeyConfig(triggerType: .freeSpeak, keyCode: 58, modifiers: [], interval: 0.3), "should have display string"),
            (HotkeyConfig(triggerType: .combination, keyCode: 49, modifiers: [.command], interval: 0.3), "should have display string")
        ]

        // When/Then: Each config should have a non-empty display string
        for (config, expectedBehavior) in configs {
            hotkeyManager.updateConfig(config)
            let displayString = config.displayString

            XCTAssertFalse(displayString.isEmpty, "Config \(expectedBehavior)")
        }
    }

    // MARK: - Persistence Tests

    func testMultipleSaveLoadCycles() {
        // Given: Multiple configurations to save and load
        let configs = [
            HotkeyConfig(triggerType: .longPress, keyCode: 58, modifiers: [], interval: 0.3),
            HotkeyConfig(triggerType: .doubleTap, keyCode: 59, modifiers: [], interval: 0.4),
            HotkeyConfig(triggerType: .freeSpeak, keyCode: 61, modifiers: [], interval: 0.5)
        ]

        // When/Then: Each save-load cycle should preserve the config
        for config in configs {
            hotkeyManager.saveConfig(config)

            let newManager = HotkeyManager()
            let loadedConfig = newManager.getCurrentConfig()

            XCTAssertEqual(loadedConfig.triggerType, config.triggerType, "Trigger type should persist")
            XCTAssertEqual(loadedConfig.keyCode, config.keyCode, "Key code should persist")
            XCTAssertEqual(loadedConfig.interval, config.interval, accuracy: 0.01, "Interval should persist")

            newManager.resetToDefault()
        }
    }
}
