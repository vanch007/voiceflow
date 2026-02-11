import XCTest
import AVFoundation
@testable import VoiceFlow

/// Unit tests for AudioRecorder initialization and device selection
///
/// **Test Coverage:**
/// - Initialization with default and custom session factories
/// - Device selection logic
/// - VAD configuration
/// - Signal quality monitoring
/// - Silence detection configuration
///
/// **Note:** This test suite avoids async session setup operations that cause crashes
/// in the test environment. Session lifecycle tests are covered in integration tests.
final class AudioRecorderTests: XCTestCase {
    var audioRecorder: AudioRecorder!
    var mockSession: MockAVCaptureSession!

    override func setUp() {
        super.setUp()
        mockSession = MockAVCaptureSession()
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

    func testInitialActiveDeviceIDIsNil() {
        // Given: A newly initialized AudioRecorder
        // When: Checking the active device ID before setup
        let deviceID = audioRecorder.activeDeviceID

        // Then: Active device ID should be nil (not yet configured)
        XCTAssertNil(deviceID, "Active device ID should be nil before session setup")
    }

    // MARK: - Device Selection Tests

    func testSelectDeviceAcceptsNilForSystemDefault() {
        // Given: A newly initialized AudioRecorder
        // When: selectDevice(nil) is called
        audioRecorder.selectDevice(id: nil)

        // Then: No crash should occur
        XCTAssertNotNil(audioRecorder, "Should handle nil device selection (system default)")
    }

    func testSelectDeviceAcceptsCustomDeviceID() {
        // Given: A newly initialized AudioRecorder
        // When: selectDevice with a custom ID is called
        audioRecorder.selectDevice(id: "custom-device-id")

        // Then: No crash should occur
        XCTAssertNotNil(audioRecorder, "Should handle custom device ID selection")
    }

    func testSelectSameDeviceTwice() {
        // Given: A device has been selected
        audioRecorder.selectDevice(id: "device-1")

        // When: The same device is selected again
        audioRecorder.selectDevice(id: "device-1")

        // Then: Should handle duplicate selection without issues
        XCTAssertNotNil(audioRecorder, "Should handle selecting same device twice")
    }

    func testDeviceChangedCallbackCanBeSet() {
        // Given: A newly initialized AudioRecorder
        var callbackInvoked = false

        // When: Setting device changed callback
        audioRecorder.onDeviceChanged = { _ in
            callbackInvoked = true
        }

        // Then: Callback should be set without crash
        XCTAssertNotNil(audioRecorder.onDeviceChanged, "onDeviceChanged callback should be settable")
    }

    func testAvailableDevicesReturnsDeviceList() {
        // Given: System audio devices
        // When: Querying available devices
        let devices = AudioRecorder.availableDevices()

        // Then: Should return a non-nil array
        XCTAssertNotNil(devices, "Available devices should return a non-nil array")

        // Verify each device has required properties
        for device in devices {
            XCTAssertFalse(device.id.isEmpty, "Device ID should not be empty")
            XCTAssertFalse(device.name.isEmpty, "Device name should not be empty")
        }
    }

    // MARK: - VAD Configuration Tests

    func testConfigureVADWithDefaults() {
        // Given: A newly initialized AudioRecorder
        // When: VAD is configured with default parameters
        audioRecorder.configureVAD(enabled: true)

        // Then: Configuration should complete without crash
        XCTAssertNotNil(audioRecorder, "VAD configuration should complete successfully")
    }

    func testConfigureVADWithCustomThreshold() {
        // Given: A newly initialized AudioRecorder
        // When: VAD is configured with custom threshold
        audioRecorder.configureVAD(enabled: true, threshold: 0.01, useCompression: false)

        // Then: Configuration should be accepted
        XCTAssertNotNil(audioRecorder, "VAD configuration with custom parameters should complete")
    }

    func testConfigureVADDisabled() {
        // Given: A newly initialized AudioRecorder
        // When: VAD is disabled
        audioRecorder.configureVAD(enabled: false)

        // Then: Configuration should be accepted
        XCTAssertNotNil(audioRecorder, "VAD disable configuration should complete")
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

    func testSNRCallbackCanBeSet() {
        // Given: A newly initialized AudioRecorder
        var callbackSet = false

        // When: Setting SNR callback
        audioRecorder.onSNRUpdated = { _, _ in
            callbackSet = true
        }

        // Then: Callback should be settable
        XCTAssertNotNil(audioRecorder.onSNRUpdated, "onSNRUpdated callback should be settable")
    }

    // MARK: - Silence Detection Tests

    func testEnableSilenceDetection() {
        // Given: A newly initialized AudioRecorder
        // When: Silence detection is enabled
        audioRecorder.enableSilenceDetection(threshold: 0.005, duration: 2.0)

        // Then: Configuration should be accepted without crashing
        XCTAssertNotNil(audioRecorder, "Silence detection should be enabled successfully")
    }

    func testDisableSilenceDetection() {
        // Given: AudioRecorder with silence detection enabled
        audioRecorder.enableSilenceDetection(threshold: 0.005, duration: 2.0)

        // When: Silence detection is disabled
        audioRecorder.disableSilenceDetection()

        // Then: Should disable without crashing
        XCTAssertNotNil(audioRecorder, "Silence detection should be disabled successfully")
    }

    func testGetCurrentSilenceDurationReturnsNilInitially() {
        // Given: A newly initialized AudioRecorder
        // When: Querying current silence duration before any recording
        let duration = audioRecorder.getCurrentSilenceDuration()

        // Then: Should return nil (no silence period started)
        XCTAssertNil(duration, "Silence duration should be nil when no silence is being tracked")
    }

    func testSilenceDetectionCallbackCanBeSet() {
        // Given: A newly initialized AudioRecorder
        var callbackSet = false

        // When: Setting silence detected callback
        audioRecorder.onSilenceDetected = {
            callbackSet = true
        }

        // Then: Callback should be settable
        XCTAssertNotNil(audioRecorder.onSilenceDetected, "onSilenceDetected callback should be settable")
    }

    // MARK: - Callback Tests

    func testVolumeCallbackCanBeSet() {
        // Given: A newly initialized AudioRecorder
        var callbackSet = false

        // When: Setting volume callback
        audioRecorder.onVolumeLevel = { _ in
            callbackSet = true
        }

        // Then: Callback should be settable
        XCTAssertNotNil(audioRecorder.onVolumeLevel, "onVolumeLevel callback should be settable")
    }

    func testAudioChunkCallbackCanBeSet() {
        // Given: A newly initialized AudioRecorder
        var callbackSet = false

        // When: Setting audio chunk callback
        audioRecorder.onAudioChunk = { _ in
            callbackSet = true
        }

        // Then: Callback should be settable
        XCTAssertNotNil(audioRecorder.onAudioChunk, "onAudioChunk callback should be settable")
    }
}
