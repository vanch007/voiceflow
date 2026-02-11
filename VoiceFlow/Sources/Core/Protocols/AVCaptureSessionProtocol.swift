import AVFoundation

/// Protocol abstraction for AVCaptureSession to enable testing
protocol AVCaptureSessionProtocol: AnyObject {
    var inputs: [AVCaptureInput] { get }
    var outputs: [AVCaptureOutput] { get }

    func startRunning()
    func stopRunning()
    func canAddInput(_ input: AVCaptureInput) -> Bool
    func addInput(_ input: AVCaptureInput)
    func removeInput(_ input: AVCaptureInput)
    func canAddOutput(_ output: AVCaptureOutput) -> Bool
    func addOutput(_ output: AVCaptureOutput)
    func removeOutput(_ output: AVCaptureOutput)
}

/// Extension to make AVCaptureSession conform to the protocol
extension AVCaptureSession: AVCaptureSessionProtocol {}
