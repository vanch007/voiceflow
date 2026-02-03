import AVFoundation
import CoreMedia
import CoreAudio

final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    var onAudioChunk: ((Data) -> Void)?
    var onVolumeLevel: ((Float) -> Void)?
    var onDeviceChanged: ((String) -> Void)?

    private var captureSession: AVCaptureSession?
    private let sessionQueue = DispatchQueue(label: "com.voiceflow.capture")
    private let targetSampleRate: Double = 16000
    private var isRecording = false
    private var currentDeviceID: String?
    private var selectedDeviceID: String?  // User-selected device (nil = system default)
    private var savedOutputVolume: Float32?

    /// Returns list of available audio input devices as (uniqueID, localizedName)
    static func availableDevices() -> [(id: String, name: String)] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discoverySession.devices.map { ($0.uniqueID, $0.localizedName) }
    }

    /// Select a specific audio device by uniqueID. Pass nil to use system default.
    func selectDevice(id: String?) {
        let changed = selectedDeviceID != id
        selectedDeviceID = id
        if changed {
            let name = id.flatMap { devID in
                Self.availableDevices().first(where: { $0.id == devID })?.name
            } ?? "System Default"
            NSLog("[AudioRecorder] Device selected: \(name)")
            setupSession()
        }
    }

    var activeDeviceID: String? { currentDeviceID }

    /// Call once at app startup
    func prepare() {
        setupSession()
    }

    func startRecording() {
        // Save current output volume before ducking kicks in
        savedOutputVolume = getOutputVolume()
        // Check if default device changed (only when using system default)
        if selectedDeviceID == nil,
           let newDevice = AVCaptureDevice.default(for: .audio),
           newDevice.uniqueID != currentDeviceID {
            NSLog("[AudioRecorder] Default device changed, reconnecting...")
            setupSession()
        }
        isRecording = true
        NSLog("[AudioRecorder] Recording started.")
    }

    func stopRecording() {
        isRecording = false
        // Restore output volume that macOS ducked
        if let volume = savedOutputVolume {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setOutputVolume(volume)
                NSLog("[AudioRecorder] Output volume restored to \(volume)")
            }
            savedOutputVolume = nil
        }
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

            // Use selected device, or fall back to system default
            let device: AVCaptureDevice?
            if let selectedID = self.selectedDeviceID {
                device = AVCaptureDevice(uniqueID: selectedID)
            } else {
                device = AVCaptureDevice.default(for: .audio)
            }

            guard let device else {
                NSLog("[AudioRecorder] No audio device found!")
                return
            }

            NSLog("[AudioRecorder] Audio device: \(device.localizedName)")
            self.currentDeviceID = device.uniqueID
            DispatchQueue.main.async {
                self.onDeviceChanged?(device.localizedName)
            }

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

    // MARK: - CoreAudio Device Enumeration

    private func enumerateInputDevices() -> [(id: AudioDeviceID, name: String)] {
        var devices: [(id: AudioDeviceID, name: String)] = []

        // Get all audio devices
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Get size of device array
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size
        )
        guard status == noErr else { return devices }

        // Get device IDs
        let deviceCount = Int(size) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceIDs
        )
        guard status == noErr else { return devices }

        // Filter for input devices and get their names
        for deviceID in deviceIDs {
            // Check if device has input streams
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize)
            guard status == noErr, streamSize > 0 else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
            var nameRef: Unmanaged<CFString>?
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef)
            guard status == noErr, let nameRef else { continue }

            let name = nameRef.takeUnretainedValue() as String
            devices.append((id: deviceID, name: name))
        }

        return devices
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>>.size)
        var nameRef: Unmanaged<CFString>?
        let status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &nameRef)
        guard status == noErr, let nameRef else { return nil }

        return nameRef.takeUnretainedValue() as String
    }

    // MARK: - Output Volume (CoreAudio)

    private func getDefaultInputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func getDefaultOutputDeviceID() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID
        )
        return status == noErr ? deviceID : nil
    }

    private func getOutputVolume() -> Float32? {
        guard let deviceID = getDefaultOutputDeviceID() else { return nil }
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)
        return status == noErr ? volume : nil
    }

    private func setOutputVolume(_ volume: Float32) {
        guard let deviceID = getDefaultOutputDeviceID() else { return }
        var vol = volume
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<Float32>.size), &vol
        )
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
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        // For non-interleaved audio, mBytesPerFrame is per-channel,
        // so length / mBytesPerFrame gives totalFrames * channels.
        // We need to divide by channels to get the actual frame count.
        let frameCount: Int
        if isNonInterleaved {
            frameCount = length / bytesPerFrame / channels
        } else {
            frameCount = length / bytesPerFrame
        }
        guard frameCount > 0 else { return }

        let floatSamples: [Float]
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let floatPtr = ptr.bindMemory(to: Float.self)
                if isNonInterleaved || channels == 1 {
                    // Non-interleaved: [ch0_0, ch0_1, ..., ch0_N, ch1_0, ...]
                    // Just take the first frameCount samples (channel 0)
                    return Array(floatPtr.prefix(frameCount))
                } else {
                    // Interleaved: [L, R, L, R, ...]
                    return stride(from: 0, to: frameCount * channels, by: channels).map { floatPtr[$0] }
                }
            }
        } else if asbd.mBitsPerChannel == 16 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let int16Ptr = ptr.bindMemory(to: Int16.self)
                if isNonInterleaved || channels == 1 {
                    return int16Ptr.prefix(frameCount).map { Float($0) / 32768.0 }
                } else {
                    return stride(from: 0, to: frameCount * channels, by: channels).map { Float(int16Ptr[$0]) / 32768.0 }
                }
            }
        } else if asbd.mBitsPerChannel == 32 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let int32Ptr = ptr.bindMemory(to: Int32.self)
                if isNonInterleaved || channels == 1 {
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

        // Calculate volume level (RMS)
        let rms = sqrt(output.map { $0 * $0 }.reduce(0, +) / Float(output.count))
        onVolumeLevel?(rms)
    }
}
