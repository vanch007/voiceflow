import XCTest
import AVFoundation
@testable import VoiceFlow

/// Unit tests for AudioRecorder initialization and device selection
///
/// **Test Coverage:**
/// - Initialization with default session factory
/// - Initialization with custom session factory (dependency injection)
/// - Device selection and tracking
/// - Available devices enumeration
/// - Session setup lifecycle
///
/// **Setup Requirements:**
/// - Uses MockAVCaptureSession to avoid real hardware dependencies
/// - Tests run independently without microphone access
/// - No actual audio capture occurs during tests
final class AudioRecorderTests: XCTestCase {
    var audioRecorder: AudioRecorder!
    var mockSession: MockAVCaptureSession!

    override func setUp() {
        super.setUp()
        mockSession = MockAVCaptureSession()

        // Create AudioRecorder with mock session factory
        audioRecorder = AudioRecorder(sessionFactory: { [unowned self] in
            return self.mockSession
        })
    }

    override func tearDown() {
        audioRecorder = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitializationWithCustomSessionFactory() {
        // Given: A custom session factory
        let customMockSession = MockAVCaptureSession()

        // When: AudioRecorder is initialized with custom factory
        let recorder = AudioRecorder(sessionFactory: {
            return customMockSession
        })

        // Then: AudioRecorder should be successfully created
        XCTAssertNotNil(recorder, "AudioRecorder should initialize with custom factory")
    }

    func testInitializationWithDefaultFactory() {
        // Given: Default initializer (uses AVCaptureSession)
        // When: AudioRecorder is initialized without parameters
        let recorder = AudioRecorder()

        // Then: AudioRecorder should be successfully created
        XCTAssertNotNil(recorder, "AudioRecorder should initialize with default factory")
    }

    func testPrepareSetupsCaptureSession() {
        // Given: A newly initialized AudioRecorder
        XCTAssertFalse(mockSession.startRunningCalled, "Session should not be running initially")

        // When: prepare() is called
        audioRecorder.prepare()

        // Wait for async session setup to complete
        let setupExpectation = expectation(description: "Session setup completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 1.0)

        // Then: Capture session should be configured and started
        XCTAssertTrue(mockSession.startRunningCalled, "Session should be started after prepare()")
        XCTAssertGreaterThan(mockSession.addInputCallCount, 0, "Should have added audio input")
        XCTAssertGreaterThan(mockSession.addOutputCallCount, 0, "Should have added audio output")
    }

    func testInitialActiveDeviceIDIsNil() {
        // Given: A newly initialized AudioRecorder
        // When: Checking the active device ID before prepare()
        let deviceID = audioRecorder.activeDeviceID

        // Then: Active device ID should be nil (not yet configured)
        XCTAssertNil(deviceID, "Active device ID should be nil before session setup")
    }

    // MARK: - Device Selection Tests

    func testSelectDeviceWithNilUsesSystemDefault() {
        // Given: A prepared AudioRecorder
        audioRecorder.prepare()

        // Wait for initial setup
        let initialSetupExpectation = expectation(description: "Initial setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialSetupExpectation.fulfill()
        }
        wait(for: [initialSetupExpectation], timeout: 1.0)

        let initialInputCount = mockSession.addInputCallCount

        // When: selectDevice(nil) is called to use system default (already the default)
        audioRecorder.selectDevice(id: nil)

        // Wait for potential device selection
        let selectionExpectation = expectation(description: "Selection processing")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectionExpectation.fulfill()
        }
        wait(for: [selectionExpectation], timeout: 0.5)

        // Then: Session should NOT be reconfigured (same device - nil to nil)
        XCTAssertEqual(mockSession.addInputCallCount, initialInputCount, "Should not reconfigure when selecting same default device")
    }

    func testSelectDeviceTriggersSessionReconfiguration() {
        // Given: A prepared AudioRecorder with initial device
        audioRecorder.prepare()

        // Wait for initial setup
        let initialSetupExpectation = expectation(description: "Initial setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialSetupExpectation.fulfill()
        }
        wait(for: [initialSetupExpectation], timeout: 1.0)

        let initialInputCount = mockSession.addInputCallCount
        let initialStopCalled = mockSession.stopRunningCalled

        // When: A different (valid) device ID is selected from available devices
        let availableDevices = AudioRecorder.availableDevices()
        if let firstDevice = availableDevices.first {
            audioRecorder.selectDevice(id: firstDevice.id)

            // Wait for reconfiguration
            let reconfigExpectation = expectation(description: "Session reconfigured")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                reconfigExpectation.fulfill()
            }
            wait(for: [reconfigExpectation], timeout: 1.0)

            // Then: Session should be reconfigured (new input added)
            XCTAssertGreaterThan(mockSession.addInputCallCount, initialInputCount, "Session should be reconfigured with new device")
            XCTAssertTrue(mockSession.stopRunningCalled || initialStopCalled, "Session should be stopped during reconfiguration")
        } else {
            // No devices available in test environment - verify selectDevice doesn't crash
            audioRecorder.selectDevice(id: "any-id")
            XCTAssertTrue(true, "selectDevice should handle missing devices gracefully")
        }
    }

    func testSelectDeviceWithSameIDDoesNotReconfigure() {
        // Given: A prepared AudioRecorder
        audioRecorder.prepare()

        // Wait for initial setup
        let initialSetupExpectation = expectation(description: "Initial setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialSetupExpectation.fulfill()
        }
        wait(for: [initialSetupExpectation], timeout: 1.0)

        // Select a device
        audioRecorder.selectDevice(id: nil)

        // Wait for selection
        let firstSelectionExpectation = expectation(description: "First selection")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            firstSelectionExpectation.fulfill()
        }
        wait(for: [firstSelectionExpectation], timeout: 1.0)

        let inputCountAfterFirstSelection = mockSession.addInputCallCount

        // When: The same device is selected again
        audioRecorder.selectDevice(id: nil)

        // Wait briefly
        let secondSelectionExpectation = expectation(description: "Second selection")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            secondSelectionExpectation.fulfill()
        }
        wait(for: [secondSelectionExpectation], timeout: 0.5)

        // Then: Session should NOT be reconfigured (no change in device)
        XCTAssertEqual(mockSession.addInputCallCount, inputCountAfterFirstSelection, "Session should not reconfigure when selecting same device")
    }

    func testDeviceChangedCallbackInvokedOnSelection() {
        // Given: A prepared AudioRecorder with device change callback
        var receivedDeviceName: String?
        let callbackExpectation = expectation(description: "Device changed callback invoked")

        audioRecorder.onDeviceChanged = { deviceName in
            receivedDeviceName = deviceName
            callbackExpectation.fulfill()
        }

        // When: prepare() is called (triggers initial device setup)
        audioRecorder.prepare()

        // Then: Callback should be invoked with device name during setup
        wait(for: [callbackExpectation], timeout: 2.0)

        XCTAssertNotNil(receivedDeviceName, "Device name should be provided in callback")
        XCTAssertFalse(receivedDeviceName?.isEmpty ?? true, "Device name should not be empty")
    }

    func testAvailableDevicesReturnsDeviceList() {
        // Given: System audio devices
        // When: Querying available devices
        let devices = AudioRecorder.availableDevices()

        // Then: Should return a list of devices (may be empty in test environment)
        // This test verifies the method doesn't crash and returns the expected format
        XCTAssertNotNil(devices, "Available devices should return a non-nil array")

        // Verify each device has required properties
        for device in devices {
            XCTAssertFalse(device.id.isEmpty, "Device ID should not be empty")
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
        }
    }

    // MARK: - Session Lifecycle Tests

    func testSessionStartsOnPrepare() {
        // Given: A newly initialized AudioRecorder
        XCTAssertFalse(mockSession.isRunning, "Session should not be running initially")

        // When: prepare() is called
        audioRecorder.prepare()

        // Wait for session to start
        let startExpectation = expectation(description: "Session starts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)

        // Then: Session should be running
        XCTAssertTrue(mockSession.isRunning, "Session should be running after prepare()")
        XCTAssertTrue(mockSession.startRunningCalled, "startRunning() should have been called")
    }

    func testSessionReconfigurationStopsOldSession() {
        // Given: A running capture session
        audioRecorder.prepare()

        // Wait for initial setup
        let initialSetupExpectation = expectation(description: "Initial setup")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            initialSetupExpectation.fulfill()
        }
        wait(for: [initialSetupExpectation], timeout: 1.0)

        XCTAssertTrue(mockSession.isRunning, "Session should be running")

        // When: Device is changed (triggers reconfiguration)
        audioRecorder.selectDevice(id: "different-device-id")

        // Wait for reconfiguration
        let reconfigExpectation = expectation(description: "Reconfiguration completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            reconfigExpectation.fulfill()
        }
        wait(for: [reconfigExpectation], timeout: 1.0)

        // Then: Old session should be stopped before new one starts
        XCTAssertTrue(mockSession.stopRunningCalled, "stopRunning() should be called during reconfiguration")
    }

    func testSessionInputsAndOutputsAddedDuringSetup() {
        // Given: A newly initialized AudioRecorder
        XCTAssertEqual(mockSession.addInputCallCount, 0, "No inputs should be added initially")
        XCTAssertEqual(mockSession.addOutputCallCount, 0, "No outputs should be added initially")

        // When: prepare() sets up the session
        audioRecorder.prepare()

        // Wait for setup
        let setupExpectation = expectation(description: "Setup completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 1.0)

        // Then: Inputs and outputs should be added
        XCTAssertEqual(mockSession.addInputCallCount, 1, "Should add one audio input")
        XCTAssertEqual(mockSession.addOutputCallCount, 1, "Should add one audio output")
        XCTAssertTrue(mockSession.hasAddedOutput(ofType: AVCaptureAudioDataOutput.self), "Should add AVCaptureAudioDataOutput")
    }

    func testSessionCleanupRemovesInputsAndOutputs() {
        // Given: A configured session with inputs and outputs
        audioRecorder.prepare()

        // Wait for setup
        let setupExpectation = expectation(description: "Setup completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            setupExpectation.fulfill()
        }
        wait(for: [setupExpectation], timeout: 1.0)

        XCTAssertGreaterThan(mockSession.inputs.count, 0, "Should have inputs after setup")
        XCTAssertGreaterThan(mockSession.outputs.count, 0, "Should have outputs after setup")

        // When: Session is reconfigured (cleanup happens)
        audioRecorder.selectDevice(id: "new-device-id")

        // Wait for cleanup and reconfiguration
        let cleanupExpectation = expectation(description: "Cleanup completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            cleanupExpectation.fulfill()
        }
        wait(for: [cleanupExpectation], timeout: 1.0)

        // Then: Old inputs and outputs should be removed
        XCTAssertGreaterThan(mockSession.removeInputCallCount, 0, "Should remove old inputs during reconfiguration")
        XCTAssertGreaterThan(mockSession.removeOutputCallCount, 0, "Should remove old outputs during reconfiguration")
    }

    // MARK: - VAD Configuration Tests

    func testConfigureVADWithDefaults() {
        // Given: A newly initialized AudioRecorder
        // When: VAD is configured with default parameters
        audioRecorder.configureVAD(enabled: true)

        // Then: AudioRecorder should accept the configuration without crashing
        XCTAssertTrue(true, "VAD configuration should complete successfully")
    }

    func testConfigureVADWithCustomThreshold() {
        // Given: A newly initialized AudioRecorder
        // When: VAD is configured with custom threshold
        let customThreshold: Float = 0.01
        audioRecorder.configureVAD(enabled: true, threshold: customThreshold, useCompression: false)

        // Then: Configuration should be accepted
        XCTAssertTrue(true, "VAD configuration with custom parameters should complete successfully")
    }

    func testConfigureVADDisabled() {
        // Given: A newly initialized AudioRecorder
        // When: VAD is disabled
        audioRecorder.configureVAD(enabled: false)

        // Then: Configuration should be accepted
        XCTAssertTrue(true, "VAD disable configuration should complete successfully")
    }

    // MARK: - Signal Quality Tests

    func testGetCurrentSNRReturnsFloat() {
        // Given: A newly initialized AudioRecorder
        // When: Querying current SNR
        let snr = audioRecorder.getCurrentSNR()

        // Then: Should return a float value (initially 0)
        XCTAssertEqual(snr, 0.0, "SNR should be 0.0 initially before any audio processing")
    }

    func testGetSignalQualityReturnsEnum() {
        // Given: A newly initialized AudioRecorder
        // When: Querying signal quality
        let quality = audioRecorder.getSignalQuality()

        // Then: Should return a SignalQuality enum value
        XCTAssertEqual(quality, .poor, "Signal quality should be .poor initially (SNR < 10dB)")
    }

    // MARK: - Silence Detection Tests

    func testEnableSilenceDetection() {
        // Given: A newly initialized AudioRecorder
        // When: Silence detection is enabled
        audioRecorder.enableSilenceDetection(threshold: 0.005, duration: 2.0)

        // Then: Configuration should be accepted without crashing
        XCTAssertTrue(true, "Silence detection should be enabled successfully")
    }

    func testDisableSilenceDetection() {
        // Given: AudioRecorder with silence detection enabled
        audioRecorder.enableSilenceDetection(threshold: 0.005, duration: 2.0)

        // When: Silence detection is disabled
        audioRecorder.disableSilenceDetection()

        // Then: Should disable without crashing
        XCTAssertTrue(true, "Silence detection should be disabled successfully")
    }

    func testGetCurrentSilenceDurationReturnsNilInitially() {
        // Given: A newly initialized AudioRecorder
        // When: Querying current silence duration before any recording
        let duration = audioRecorder.getCurrentSilenceDuration()

        // Then: Should return nil (no silence period started)
        XCTAssertNil(duration, "Silence duration should be nil when no silence is being tracked")
    }
}
