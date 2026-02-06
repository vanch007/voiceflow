import AVFoundation
import CoreMedia
import CoreAudio
import Accelerate

final class AudioRecorder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    var onAudioChunk: ((Data) -> Void)?
    var onVolumeLevel: ((Float) -> Void)?
    var onDeviceChanged: ((String) -> Void)?
    var onSilenceDetected: (() -> Void)?  // 静音检测回调（自由说话模式）

    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private let sessionQueue = DispatchQueue(label: "com.voiceflow.capture")
    private let targetSampleRate: Double = 16000
    private var isRecording = false
    private var currentDeviceID: String?
    private var selectedDeviceID: String?  // User-selected device (nil = system default)
    private var savedOutputVolume: Float32?

    // 静音检测相关
    private var silenceThreshold: Float = 0.005  // RMS 阈值
    private var silenceDuration: TimeInterval = 2.0  // 需要持续静音的时间（秒）
    private var silenceStartTime: Date?
    private var isSilenceDetectionEnabled = false

    // VAD 预筛和音频压缩配置
    // 注意：VAD 预筛默认禁用，因为会导致音频不连续，ASR 识别质量下降
    // 服务端有独立的 VAD 流式转录，负责停顿检测和实时预览
    private var vadEnabled = false  // 是否启用 VAD 预筛（跳过纯静音块）
    private var vadThreshold: Float = 0.005  // VAD 静音阈值
    private var useInt16Compression = true  // 是否使用 Int16 压缩传输

    // 噪声环境自适应
    private var noiseFloorWindow: [Float] = []  // 滑动窗口追踪噪声底线
    private let noiseFloorWindowSize = 50  // 约5秒（每100ms一个采样）
    private var currentNoiseFloor: Float = 0.0
    private var currentSNR: Float = 0.0
    var onSNRUpdated: ((Float, Float) -> Void)?  // (snr, noiseFloor) 回调

    /// 配置 VAD 预筛和音频压缩
    func configureVAD(enabled: Bool, threshold: Float = 0.005, useCompression: Bool = true) {
        vadEnabled = enabled
        vadThreshold = threshold
        useInt16Compression = useCompression
        NSLog("[AudioRecorder] VAD configured: enabled=\(enabled), threshold=\(threshold), compression=\(useCompression)")
    }

    /// 更新噪声底线和 SNR
    private func updateNoiseFloor(rms: Float) {
        // 添加到滑动窗口
        noiseFloorWindow.append(rms)
        if noiseFloorWindow.count > noiseFloorWindowSize {
            noiseFloorWindow.removeFirst()
        }

        // 计算噪声底线（窗口中的最小值）
        if let minRMS = noiseFloorWindow.min(), minRMS > 0 {
            currentNoiseFloor = minRMS

            // 计算 SNR: 20 * log10(signal_rms / noise_floor_rms)
            if rms > currentNoiseFloor {
                currentSNR = 20 * log10(rms / currentNoiseFloor)
            } else {
                currentSNR = 0
            }

            // 每秒更新一次 SNR 回调（避免过于频繁）
            if noiseFloorWindow.count % 10 == 0 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.onSNRUpdated?(self.currentSNR, self.currentNoiseFloor)
                }
            }
        }
    }

    /// 获取当前 SNR（信噪比）
    func getCurrentSNR() -> Float {
        return currentSNR
    }

    /// 获取信号质量等级（用于 UI 显示）
    func getSignalQuality() -> SignalQuality {
        if currentSNR >= 20 {
            return .excellent  // 绿色
        } else if currentSNR >= 10 {
            return .good  // 黄色
        } else {
            return .poor  // 红色
        }
    }

    enum SignalQuality {
        case excellent  // SNR >= 20dB
        case good       // SNR >= 10dB
        case poor       // SNR < 10dB
    }

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
        checkMicrophonePermission()
        setupSession()
    }

    private func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            NSLog("[AudioRecorder] Microphone permission: Authorized")
        case .notDetermined:
            NSLog("[AudioRecorder] Microphone permission: Not Determined")
        case .denied:
            NSLog("[AudioRecorder] Microphone permission: Denied")
        case .restricted:
            NSLog("[AudioRecorder] Microphone permission: Restricted")
        @unknown default:
            NSLog("[AudioRecorder] Microphone permission: Unknown status")
        }
    }

    /// 带回调的 startRecording，确保 isRecording 设置完成后再回调
    func startRecording(completion: @escaping () -> Void) {
        // Save current output volume before ducking kicks in
        savedOutputVolume = getOutputVolume()
        // Check if default device changed (only when using system default)
        if selectedDeviceID == nil,
           let newDevice = AVCaptureDevice.default(for: .audio),
           newDevice.uniqueID != currentDeviceID {
            NSLog("[AudioRecorder] Default device changed, reconnecting...")
            setupSession()
        }
        sessionQueue.async { [weak self] in
            self?.isRecording = true
            self?.silenceStartTime = nil  // 重置静音计时
            NSLog("[AudioRecorder] Recording started (isRecording = true)")
            DispatchQueue.main.async { completion() }
        }
    }

    /// 向后兼容的无参版本
    func startRecording() {
        startRecording(completion: {})
    }

    /// 启用自由说话模式的静音检测
    func enableSilenceDetection(threshold: Float = 0.005, duration: TimeInterval = 2.0) {
        silenceThreshold = threshold
        silenceDuration = duration
        isSilenceDetectionEnabled = true
        silenceStartTime = nil
        NSLog("[AudioRecorder] Silence detection enabled: threshold=\(threshold), duration=\(duration)s")
    }

    /// 禁用静音检测
    func disableSilenceDetection() {
        isSilenceDetectionEnabled = false
        silenceStartTime = nil
        NSLog("[AudioRecorder] Silence detection disabled")
    }

    /// 获取当前静音持续时间（用于UI显示）
    func getCurrentSilenceDuration() -> TimeInterval? {
        guard let startTime = silenceStartTime else { return nil }
        return Date().timeIntervalSince(startTime)
    }

    /// 带回调的 stopRecording，确保 isRecording 设置完成后再回调
    func stopRecording(completion: @escaping () -> Void) {
        sessionQueue.async { [weak self] in
            self?.isRecording = false
            self?.silenceStartTime = nil
            NSLog("[AudioRecorder] Recording stopped (isRecording = false)")
            DispatchQueue.main.async { completion() }
        }
        // Restore output volume that macOS ducked
        if let volume = savedOutputVolume {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setOutputVolume(volume)
                NSLog("[AudioRecorder] Output volume restored to \(volume)")
            }
            savedOutputVolume = nil
        }
    }

    /// 向后兼容的无参版本
    func stopRecording() {
        stopRecording(completion: {})
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            // Stop and clean up existing session
            if let existing = self.captureSession {
                existing.stopRunning()
                // Remove inputs
                for input in existing.inputs {
                    existing.removeInput(input)
                }
                // Remove outputs
                for output in existing.outputs {
                    existing.removeOutput(output)
                }
                // Clear delegate and release audio output reference
                self.audioOutput?.setSampleBufferDelegate(nil, queue: nil)
                self.audioOutput = nil
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
            self.audioOutput = output

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

        // Resample to 16kHz using AVAudioConverter
        let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: srcRate, channels: 1, interleaved: false)!
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false)!
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { return }
        inputBuffer.frameLength = AVAudioFrameCount(frameCount)
        // Copy mono samples into the input buffer
        if let dst = inputBuffer.floatChannelData?.pointee {
            floatSamples.withUnsafeBufferPointer { src in
                dst.assign(from: src.baseAddress!, count: frameCount)
            }
        } else {
            return
        }

        let outputCapacity = AVAudioFrameCount(Double(frameCount) * targetSampleRate / srcRate + 1)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else { return }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return }
        var conversionError: NSError?
        var providedOnce = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if providedOnce {
                outStatus.pointee = .endOfStream
                return nil
            }
            providedOnce = true
            outStatus.pointee = .haveData
            return inputBuffer
        }
        converter.convert(to: outputBuffer, error: &conversionError, withInputFrom: inputBlock)
        if let conversionError { NSLog("[AudioRecorder] AVAudioConverter error: \(conversionError)") }

        let outFrameLength = Int(outputBuffer.frameLength)
        guard outFrameLength > 0, let outPtr = outputBuffer.floatChannelData?.pointee else { return }
        let outputArray = Array(UnsafeBufferPointer(start: outPtr, count: outFrameLength))

        // Calculate volume level (RMS) using Accelerate
        let rms = vDSP.rootMeanSquare(outputArray)

        // 噪声环境自适应：更新噪声底线和 SNR
        updateNoiseFloor(rms: rms)

        // VAD 预筛：如果 RMS 低于阈值，跳过发送（减少传输量）
        if vadEnabled && rms < vadThreshold {
            // 静音块，不发送音频数据，但仍更新音量显示
            DispatchQueue.main.async { [weak self] in
                self?.onVolumeLevel?(rms)
            }
        } else {
            // 非静音块，发送音频数据
            let data: Data
            if useInt16Compression {
                // 使用 Int16 压缩（数据量减半）
                // 格式标识: 0x02 = Int16
                var compressedData = Data([0x02])
                let int16Array = outputArray.map { Int16(max(-1.0, min(1.0, $0)) * 32767) }
                int16Array.withUnsafeBufferPointer { ptr in
                    compressedData.append(UnsafeBufferPointer(start: ptr.baseAddress, count: ptr.count))
                }
                data = compressedData
            } else {
                // 原始 Float32 格式
                // 格式标识: 0x01 = Float32
                var rawData = Data([0x01])
                outputArray.withUnsafeBufferPointer { ptr in
                    rawData.append(UnsafeBufferPointer(start: ptr.baseAddress, count: ptr.count))
                }
                data = rawData
            }
            onAudioChunk?(data)

            DispatchQueue.main.async { [weak self] in
                self?.onVolumeLevel?(rms)
            }
        }

        // 静音检测逻辑（自由说话模式）
        if isSilenceDetectionEnabled && isRecording {
            if rms < silenceThreshold {
                // 低于阈值，开始或继续计时
                if silenceStartTime == nil {
                    silenceStartTime = Date()
                } else if let startTime = silenceStartTime,
                          Date().timeIntervalSince(startTime) >= silenceDuration {
                    // 静音持续时间超过阈值，触发回调
                    NSLog("[AudioRecorder] Silence detected for \(silenceDuration)s, triggering callback")
                    silenceStartTime = nil  // 重置，防止重复触发
                    DispatchQueue.main.async { [weak self] in
                        self?.onSilenceDetected?()
                    }
                }
            } else {
                // 高于阈值，重置计时
                silenceStartTime = nil
            }
        }
    }

    deinit {
        sessionQueue.sync {
            self.captureSession?.stopRunning()
            if let existing = self.captureSession {
                for input in existing.inputs { existing.removeInput(input) }
                for output in existing.outputs { existing.removeOutput(output) }
            }
            self.audioOutput?.setSampleBufferDelegate(nil, queue: nil)
            self.audioOutput = nil
            self.captureSession = nil
        }
    }
}
