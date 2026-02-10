import AVFoundation
@testable import VoiceFlow

/// Mock implementation of AVCaptureSessionProtocol for testing AudioRecorder logic
///
/// This mock allows tests to:
/// - Track method calls (startRunning, stopRunning, addInput, removeInput, etc.)
/// - Control behavior (canAddInput, canAddOutput return values)
/// - Verify capture session lifecycle without real hardware dependencies
/// - Test audio recorder setup and teardown logic
final class MockAVCaptureSession: AVCaptureSessionProtocol {

    // MARK: - AVCaptureSessionProtocol Properties

    /// Current inputs in the mock session
    private(set) var inputs: [AVCaptureInput] = []

    /// Current outputs in the mock session
    private(set) var outputs: [AVCaptureOutput] = []

    // MARK: - Call Tracking Properties

    /// Tracks whether startRunning() was called
    var startRunningCalled = false

    /// Tracks whether stopRunning() was called
    var stopRunningCalled = false

    /// Number of times addInput() was called
    var addInputCallCount = 0

    /// Number of times removeInput() was called
    var removeInputCallCount = 0

    /// Number of times addOutput() was called
    var addOutputCallCount = 0

    /// Number of times removeOutput() was called
    var removeOutputCallCount = 0

    /// Number of times canAddInput() was called
    var canAddInputCallCount = 0

    /// Number of times canAddOutput() was called
    var canAddOutputCallCount = 0

    /// Tracks all inputs that were added
    var addedInputs: [AVCaptureInput] = []

    /// Tracks all inputs that were removed
    var removedInputs: [AVCaptureInput] = []

    /// Tracks all outputs that were added
    var addedOutputs: [AVCaptureOutput] = []

    /// Tracks all outputs that were removed
    var removedOutputs: [AVCaptureOutput] = []

    // MARK: - Behavior Configuration Properties

    /// Return value for canAddInput() (default: true)
    var canAddInputReturnValue = true

    /// Return value for canAddOutput() (default: true)
    var canAddOutputReturnValue = true

    /// Whether the session is currently running (tracked internally)
    private(set) var isRunning = false

    // MARK: - AVCaptureSessionProtocol Implementation

    func startRunning() {
        startRunningCalled = true
        isRunning = true
    }

    func stopRunning() {
        stopRunningCalled = true
        isRunning = false
    }

    func canAddInput(_ input: AVCaptureInput) -> Bool {
        canAddInputCallCount += 1
        return canAddInputReturnValue
    }

    func addInput(_ input: AVCaptureInput) {
        addInputCallCount += 1
        addedInputs.append(input)
        inputs.append(input)
    }

    func removeInput(_ input: AVCaptureInput) {
        removeInputCallCount += 1
        removedInputs.append(input)
        inputs.removeAll { $0 === input }
    }

    func canAddOutput(_ output: AVCaptureOutput) -> Bool {
        canAddOutputCallCount += 1
        return canAddOutputReturnValue
    }

    func addOutput(_ output: AVCaptureOutput) {
        addOutputCallCount += 1
        addedOutputs.append(output)
        outputs.append(output)
    }

    func removeOutput(_ output: AVCaptureOutput) {
        removeOutputCallCount += 1
        removedOutputs.append(output)
        outputs.removeAll { $0 === output }
    }

    // MARK: - Helper Methods for Testing

    /// Reset all tracking properties and state (useful in setUp/tearDown)
    func reset() {
        // Reset tracking flags
        startRunningCalled = false
        stopRunningCalled = false
        addInputCallCount = 0
        removeInputCallCount = 0
        addOutputCallCount = 0
        removeOutputCallCount = 0
        canAddInputCallCount = 0
        canAddOutputCallCount = 0

        // Reset tracking arrays
        addedInputs.removeAll()
        removedInputs.removeAll()
        addedOutputs.removeAll()
        removedOutputs.removeAll()

        // Reset state
        inputs.removeAll()
        outputs.removeAll()
        isRunning = false

        // Reset behavior configuration
        canAddInputReturnValue = true
        canAddOutputReturnValue = true
    }

    /// Check if a specific input type was added
    /// - Parameter type: The type of input to check for
    /// - Returns: True if an input of the specified type was added
    func hasAddedInput<T: AVCaptureInput>(ofType type: T.Type) -> Bool {
        return addedInputs.contains { $0 is T }
    }

    /// Check if a specific output type was added
    /// - Parameter type: The type of output to check for
    /// - Returns: True if an output of the specified type was added
    func hasAddedOutput<T: AVCaptureOutput>(ofType type: T.Type) -> Bool {
        return addedOutputs.contains { $0 is T }
    }

    /// Get the first added input of a specific type
    /// - Parameter type: The type of input to retrieve
    /// - Returns: The first input of the specified type, or nil if not found
    func getAddedInput<T: AVCaptureInput>(ofType type: T.Type) -> T? {
        return addedInputs.first { $0 is T } as? T
    }

    /// Get the first added output of a specific type
    /// - Parameter type: The type of output to retrieve
    /// - Returns: The first output of the specified type, or nil if not found
    func getAddedOutput<T: AVCaptureOutput>(ofType type: T.Type) -> T? {
        return addedOutputs.first { $0 is T } as? T
    }

    /// Verify that the session was properly set up (inputs/outputs added, running started)
    /// - Returns: True if session has inputs, outputs, and was started
    func isProperlyConfigured() -> Bool {
        return !inputs.isEmpty && !outputs.isEmpty && startRunningCalled
    }

    /// Verify that the session was properly torn down (stopped, inputs/outputs removed)
    /// - Returns: True if session was stopped and all resources cleaned up
    func isProperlyTornDown() -> Bool {
        return stopRunningCalled && inputs.isEmpty && outputs.isEmpty
    }
}
