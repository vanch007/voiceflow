import AVFoundation

/// Protocol abstraction for AVCaptureSession to enable dependency injection and testing
///
/// This protocol defines the essential capture session interface used by AudioRecorder,
/// allowing tests to substitute a mock implementation without requiring real hardware.
protocol AVCaptureSessionProtocol {
    /// Current inputs in the session
    var inputs: [AVCaptureInput] { get }

    /// Current outputs in the session
    var outputs: [AVCaptureOutput] { get }

    /// Start the capture session
    func startRunning()

    /// Stop the capture session
    func stopRunning()

    /// Check if an input can be added to the session
    /// - Parameter input: The input to check
    /// - Returns: True if the input can be added
    func canAddInput(_ input: AVCaptureInput) -> Bool

    /// Add an input to the session
    /// - Parameter input: The input to add
    func addInput(_ input: AVCaptureInput)

    /// Remove an input from the session
    /// - Parameter input: The input to remove
    func removeInput(_ input: AVCaptureInput)

    /// Check if an output can be added to the session
    /// - Parameter output: The output to check
    /// - Returns: True if the output can be added
    func canAddOutput(_ output: AVCaptureOutput) -> Bool

    /// Add an output to the session
    /// - Parameter output: The output to add
    func addOutput(_ output: AVCaptureOutput)

    /// Remove an output from the session
    /// - Parameter output: The output to remove
    func removeOutput(_ output: AVCaptureOutput)
}

/// Extension to make AVCaptureSession conform to AVCaptureSessionProtocol
extension AVCaptureSession: AVCaptureSessionProtocol {}
