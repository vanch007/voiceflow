import Foundation
import AVFoundation
import Accelerate

/// 系统音频录制器 - 使用 BlackHole 虚拟音频设备捕获系统音频
/// 需要在系统设置中创建"多输出设备"将音频同时输出到扬声器和 BlackHole
final class SystemAudioRecorder: NSObject {
    var onAudioChunk: ((Data) -> Void)?
    var onVolumeLevel: ((Float) -> Void)?
    var onError: ((Error) -> Void)?

    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var isRecording = false
    private let processingQueue = DispatchQueue(label: "com.voiceflow.systemaudio")
    private let targetSampleRate: Double = 16000
    private var audioChunkCount = 0

    // 音频格式转换
    private var audioConverter: AVAudioConverter?
    private var cachedInputFormat: AVAudioFormat?
    private var cachedOutputFormat: AVAudioFormat?
    private var cachedSrcRate: Double = 0

    /// 查找 BlackHole 2ch 音频设备
    private func findBlackHoleDevice() -> AVCaptureDevice? {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        ).devices

        fileLog("Available audio devices:")
        for device in devices {
            fileLog("  - \(device.localizedName) (uid: \(device.uniqueID))")
        }

        // 查找 BlackHole 设备
        if let blackhole = devices.first(where: { $0.localizedName.contains("BlackHole") }) {
            fileLog("Found BlackHole device: \(blackhole.localizedName)")
            return blackhole
        }

        fileLog("BlackHole device not found!")
        return nil
    }

    /// 开始录制系统音频
    func startRecording(completion: @escaping (Bool) -> Void) {
        guard !isRecording else {
            fileLog("Already recording")
            completion(true)
            return
        }

        fileLog("startRecording called")

        guard let device = findBlackHoleDevice() else {
            fileLog("ERROR: BlackHole device not found. Please install BlackHole: https://existential.audio/blackhole/")
            DispatchQueue.main.async {
                self.onError?(NSError(domain: "SystemAudioRecorder", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "BlackHole 虚拟音频设备未找到。请先安装 BlackHole。"]))
                completion(false)
            }
            return
        }

        do {
            let session = AVCaptureSession()
            let input = try AVCaptureDeviceInput(device: device)

            guard session.canAddInput(input) else {
                fileLog("ERROR: Cannot add BlackHole input to session")
                DispatchQueue.main.async { completion(false) }
                return
            }
            session.addInput(input)

            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: processingQueue)

            guard session.canAddOutput(output) else {
                fileLog("ERROR: Cannot add audio output to session")
                DispatchQueue.main.async { completion(false) }
                return
            }
            session.addOutput(output)

            self.captureSession = session
            self.audioOutput = output
            self.isRecording = true
            self.audioChunkCount = 0

            session.startRunning()
            fileLog("AVCaptureSession started with BlackHole device")

            DispatchQueue.main.async { completion(true) }
        } catch {
            fileLog("ERROR: Failed to setup capture session: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.onError?(error)
                completion(false)
            }
        }
    }

    /// 无参版本
    func startRecording() {
        startRecording(completion: { _ in })
    }

    /// 停止录制
    func stopRecording(completion: @escaping () -> Void) {
        guard isRecording else {
            fileLog("Not recording")
            completion()
            return
        }

        captureSession?.stopRunning()
        isRecording = false
        captureSession = nil
        audioOutput = nil
        audioConverter = nil
        cachedInputFormat = nil
        cachedOutputFormat = nil
        cachedSrcRate = 0

        fileLog("Recording stopped, total chunks: \(audioChunkCount)")
        DispatchQueue.main.async { completion() }
    }

    /// 无参版本
    func stopRecording() {
        stopRecording(completion: {})
    }

    /// 检查是否正在录制
    var isCurrentlyRecording: Bool {
        return isRecording
    }

    // MARK: - File Logging

    private func fileLog(_ message: String) {
        FileLogger.shared.log(message, to: "system_audio.log")
    }

    deinit {
        captureSession?.stopRunning()
        captureSession = nil
    }
}

// MARK: - AVCaptureAudioDataOutputSampleBufferDelegate

extension SystemAudioRecorder: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isRecording else { return }

        audioChunkCount += 1
        if audioChunkCount <= 5 || audioChunkCount % 100 == 0 {
            let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
            fileLog("Audio chunk #\(audioChunkCount), samples=\(numSamples)")
        }

        guard CMSampleBufferIsValid(sampleBuffer) else { return }
        let numSamples = CMSampleBufferGetNumSamples(sampleBuffer)
        guard numSamples > 0 else { return }

        // 获取音频格式
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee else {
            return
        }

        // 获取音频数据
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var rawData = Data(count: length)
        let status = rawData.withUnsafeMutableBytes { ptr in
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: ptr.baseAddress!)
        }
        guard status == kCMBlockBufferNoErr else { return }

        let srcRate = asbd.mSampleRate
        let channels = Int(asbd.mChannelsPerFrame)
        let bytesPerFrame = Int(asbd.mBytesPerFrame)
        let isNonInterleaved = (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) != 0

        let frameCount: Int
        if isNonInterleaved {
            frameCount = length / bytesPerFrame / channels
        } else {
            frameCount = length / bytesPerFrame
        }
        guard frameCount > 0 else { return }

        // 转换为 Float32 单声道
        let floatSamples: [Float]
        if asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0 {
            floatSamples = rawData.withUnsafeBytes { ptr in
                let floatPtr = ptr.bindMemory(to: Float.self)
                if isNonInterleaved || channels == 1 {
                    return Array(floatPtr.prefix(frameCount))
                } else {
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

        // 重采样到 16kHz
        if cachedSrcRate != srcRate {
            cachedSrcRate = srcRate
            cachedInputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: srcRate, channels: 1, interleaved: false)
            cachedOutputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetSampleRate, channels: 1, interleaved: false)
            if let inf = cachedInputFormat, let outf = cachedOutputFormat {
                audioConverter = AVAudioConverter(from: inf, to: outf)
            }
        }

        guard let inputFmt = cachedInputFormat,
              let outputFmt = cachedOutputFormat,
              let converter = audioConverter,
              let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFmt, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }

        inputBuffer.frameLength = AVAudioFrameCount(frameCount)
        guard let dst = inputBuffer.floatChannelData?.pointee else { return }
        floatSamples.withUnsafeBufferPointer { src in
            dst.update(from: src.baseAddress!, count: frameCount)
        }

        let outputCapacity = AVAudioFrameCount(Double(frameCount) * targetSampleRate / srcRate + 1)
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFmt, frameCapacity: outputCapacity) else {
            return
        }

        var conversionError: NSError?
        converter.reset()  // 重置 converter 内部状态，防止前次 endOfStream 导致后续转换返回 0 帧
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

        guard conversionError == nil else { return }

        let outFrameLength = Int(outputBuffer.frameLength)
        guard outFrameLength > 0, let outPtr = outputBuffer.floatChannelData?.pointee else { return }
        let outputArray = Array(UnsafeBufferPointer(start: outPtr, count: outFrameLength))

        // 计算音量 (RMS)
        let rms = vDSP.rootMeanSquare(outputArray)

        // 诊断：记录音量值，确认是否全是静音
        if audioChunkCount <= 10 || audioChunkCount % 100 == 0 {
            fileLog("RMS volume=#\(audioChunkCount): \(rms) (silent=\(rms < 0.001))")
        }

        DispatchQueue.main.async { [weak self] in
            self?.onVolumeLevel?(rms)
        }

        // Int16 压缩传输（与 AudioRecorder 一致）
        var compressedData = Data([0x02])
        let int16Array = outputArray.map { Int16(max(-1.0, min(1.0, $0)) * 32767) }
        int16Array.withUnsafeBufferPointer { ptr in
            compressedData.append(UnsafeBufferPointer(start: ptr.baseAddress, count: ptr.count))
        }
        onAudioChunk?(compressedData)
    }
}
