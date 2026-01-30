import AVFoundation
import CoreMedia

final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    var onAudioChunk: ((Data) -> Void)?

    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.voiceflow.capture")
    private let targetSampleRate: Double = 16000
    private var isRecording = false
    private var currentDeviceID: String?

    /// Call once at app startup
    func prepare() {
        setupSession()
    }

    func startRecording() {
        // Check if default device changed
        if let newDevice = AVCaptureDevice.default(for: .audio),
           newDevice.uniqueID != currentDeviceID {
            NSLog("[AudioRecorder] Device changed, reconnecting...")
            setupSession()
        }
        isRecording = true
        NSLog("[AudioRecorder] Recording started.")
    }

    func stopRecording() {
        isRecording = false
        NSLog("[AudioRecorder] Recording stopped.")
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            // Stop existing session
            if let existing = self.captureSession {
                existing.stopRunning()
            }

            let session = AVCaptureSession()

            guard let device = AVCaptureDevice.default(for: .audio) else {
                NSLog("[AudioRecorder] No audio device found!")
                return
            }

            NSLog("[AudioRecorder] Audio device: \(device.localizedName)")
            self.currentDeviceID = device.uniqueID

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
            } catch {
                NSLog("[AudioRecorder] Failed to create input: \(error)")
                return
            }

            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: self.sessionQueue)

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            self.captureSession = session
            session.startRunning()
            NSLog("[AudioRecorder] Capture session started (standby).")
        }
    }

    // MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var rawData = Data(count: length)
        rawData.withUnsafeMutableBytes { ptr in
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
        }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else { return }

        let srcRate = asbd.mSampleRate
        let channels = Int(asbd.mChannelsPerFrame)
        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        let frameCount = length / bytesPerFrame
        guard frameCount > 0 else { return }

        let floatSamples: [Float]
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let floatPtr = ptr.bindMemory(to: Float.self)
                if channels == 1 {
                    return Array(floatPtr.prefix(frameCount))
                } else {
                    return stride(from: 0, to: frameCount * channels, by: channels).map { floatPtr[$0] }
                }
            }
        } else if asbd.mBitsPerChannel == 16 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let int16Ptr = ptr.bindMemory(to: Int16.self)
                if channels == 1 {
                    return int16Ptr.prefix(frameCount).map { Float($0) / 32768.0 }
                } else {
                    return stride(from: 0, to: frameCount * channels, by: channels).map { Float(int16Ptr[$0]) / 32768.0 }
                }
            }
        } else if asbd.mBitsPerChannel == 32 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let int32Ptr = ptr.bindMemory(to: Int32.self)
                if channels == 1 {
                    return int32Ptr.prefix(frameCount).map { Float($0) / Float(Int32.max) }
                } else {
                    return stride(from: 0, to: frameCount * channels, by: channels).map { Float(int32Ptr[$0]) / Float(Int32.max) }
                }
            }
        } else {
            return
        }

        // Resample to 16kHz
        let ratio = targetSampleRate / srcRate
        let outputLength = Int(Double(floatSamples.count) * ratio)
        guard outputLength > 0 else { return }

        var output = [Float](repeating: 0, count: outputLength)
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let srcInt = Int(srcIndex)
            let frac = Float(srcIndex - Double(srcInt))
            if srcInt + 1 < floatSamples.count {
                output[i] = floatSamples[srcInt] * (1 - frac) + floatSamples[srcInt + 1] * frac
            } else if srcInt < floatSamples.count {
                output[i] = floatSamples[srcInt]
            }
        }

        let data = output.withUnsafeBufferPointer { ptr in
            Data(bytes: ptr.baseAddress!, count: ptr.count * MemoryLayout<Float>.size)
        }
        onAudioChunk?(data)
    }
}
