// AudioRecorder.swift
// Mumble
//
// Audio recording engine using AVAudioEngine.
// Captures mono 16kHz PCM audio suitable for speech-to-text,
// exposes a live RMS audio level for waveform visualization,
// and returns WAV-formatted data on stop.

import AVFoundation
import Combine
import CoreAudio
import os.log

// MARK: - Error Types

enum AudioRecorderError: LocalizedError {
    case engineStartFailed(underlying: Error)
    case inputNodeUnavailable
    case noAudioData
    case deviceSelectionFailed(uid: String)
    case formatConversionFailed
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .engineStartFailed(let underlying):
            return "Failed to start audio engine: \(underlying.localizedDescription)"
        case .inputNodeUnavailable:
            return "No audio input node available. Check that a microphone is connected."
        case .noAudioData:
            return "Recording produced no audio data."
        case .deviceSelectionFailed(let uid):
            return "Could not select audio device with UID: \(uid)"
        case .formatConversionFailed:
            return "Failed to create the required audio format for recording."
        case .microphonePermissionDenied:
            return "Microphone access is required. Grant permission in System Settings > Privacy & Security > Microphone."
        }
    }
}

// MARK: - AudioRecorder

@MainActor
final class AudioRecorder: ObservableObject {

    // MARK: Published State

    @Published private(set) var isRecording = false

    /// RMS audio level in 0.0 ... 1.0, updated from the tap block.
    /// Drive a waveform / level-meter visualisation from this value.
    @Published private(set) var audioLevel: Float = 0.0

    /// Peak audio level observed during the current (or most recent) recording session.
    /// Read this after `stopRecording()` to determine if the recording contained speech.
    private(set) var peakAudioLevel: Float = 0.0

    // MARK: Private Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mumble", category: "AudioRecorder")

    private var audioEngine: AVAudioEngine?
    private var pcmBuffers: [Data] = []
    private var recordingFormat: AVAudioFormat?

    /// Device UID selected by the user, or `nil` for the system default.
    private var selectedDeviceUID: String?

    /// Smoothing factor for the audio-level EMA (exponential moving average).
    /// Closer to 1.0 = more responsive, closer to 0.0 = smoother.
    private let levelSmoothing: Float = 0.5

    // Target recording parameters
    private let targetSampleRate: Double = 16_000
    private let targetChannelCount: AVAudioChannelCount = 1

    // MARK: - Lifecycle

    deinit {
        // Because the class is @MainActor-isolated we schedule cleanup
        // but the engine will be deallocated regardless.
        let engine = audioEngine
        audioEngine = nil
        engine?.stop()
    }

    // MARK: - Public API

    /// Returns the available audio input devices as (name, uid) tuples.
    /// Uses the CoreAudio HAL to enumerate devices.
    nonisolated func availableInputDevices() -> [(name: String, uid: String)] {
        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        // Ask how many devices exist.
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        var results: [(name: String, uid: String)] = []

        for deviceID in deviceIDs {
            // Check the device has input channels.
            var inputAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var bufferListSize: UInt32 = 0
            status = AudioObjectGetPropertyDataSize(deviceID, &inputAddress, 0, nil, &bufferListSize)
            guard status == noErr, bufferListSize > 0 else { continue }

            let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
            defer { bufferListPointer.deallocate() }
            status = AudioObjectGetPropertyData(deviceID, &inputAddress, 0, nil, &bufferListSize, bufferListPointer)
            guard status == noErr else { continue }

            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let inputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard inputChannels > 0 else { continue }

            // Device name.
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceNameCFString,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var name: CFString = "" as CFString
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, &name)
            guard status == noErr else { continue }

            // Device UID.
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            status = AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &uid)
            guard status == noErr else { continue }

            results.append((name: name as String, uid: uid as String))
        }

        return results
    }

    /// Select a specific input device by its UID.
    /// Pass `nil` to revert to the system default.
    func selectInputDevice(uid: String?) throws {
        guard let uid else {
            selectedDeviceUID = nil
            return
        }

        // Validate the UID exists in the current device list.
        let devices = availableInputDevices()
        guard devices.contains(where: { $0.uid == uid }) else {
            throw AudioRecorderError.deviceSelectionFailed(uid: uid)
        }
        selectedDeviceUID = uid
    }

    /// Begin recording. Throws on failure.
    func startRecording() throws {
        guard !isRecording else { return }

        pcmBuffers.removeAll()
        peakAudioLevel = 0.0

        let engine = AVAudioEngine()
        self.audioEngine = engine

        // Apply device selection if needed.
        if let uid = selectedDeviceUID {
            try setAudioEngineInputDevice(engine: engine, uid: uid)
        }

        let inputNode = engine.inputNode

        // Determine the hardware format so we can install a tap that the
        // input node can actually service. AVAudioEngine requires the tap
        // format's channel count to match the input node's output bus.
        let hardwareFormat = inputNode.outputFormat(forBus: 0)
        guard hardwareFormat.sampleRate > 0 else {
            throw AudioRecorderError.inputNodeUnavailable
        }

        // We request mono at the hardware sample rate for the tap, then
        // use an AVAudioConverter to get to 16 kHz mono afterwards.
        guard let tapFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: hardwareFormat.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatConversionFailed
        }

        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: targetChannelCount,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatConversionFailed
        }

        let converter = AVAudioConverter(from: tapFormat, to: outputFormat)
        guard let converter else {
            throw AudioRecorderError.formatConversionFailed
        }

        self.recordingFormat = outputFormat

        // Buffer size: ~100ms of audio at the hardware sample rate.
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(hardwareFormat.sampleRate * 0.1)

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: tapFormat) {
            [weak self] (buffer, _) in
            guard let self else { return }

            // --- RMS audio level ---
            let level = Self.rmsLevel(from: buffer)

            // --- Sample-rate conversion to 16 kHz ---
            let ratio = outputFormat.sampleRate / tapFormat.sampleRate
            let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1

            guard let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: outputFormat,
                frameCapacity: outputFrameCapacity
            ) else { return }

            var error: NSError?
            var allConsumed = false
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                if allConsumed {
                    outStatus.pointee = .noDataNow
                    return nil
                }
                allConsumed = true
                outStatus.pointee = .haveData
                return buffer
            }

            guard error == nil, convertedBuffer.frameLength > 0 else { return }

            // Append raw Float32 PCM bytes.
            if let channelData = convertedBuffer.floatChannelData?[0] {
                let byteCount = Int(convertedBuffer.frameLength) * MemoryLayout<Float>.size
                let data = Data(bytes: channelData, count: byteCount)

                Task { @MainActor [weak self] in
                    self?.pcmBuffers.append(data)
                    self?.peakAudioLevel = max(self?.peakAudioLevel ?? 0, level)
                    let smoothed = (self?.audioLevel ?? 0) * (1 - (self?.levelSmoothing ?? 0.3))
                        + level * (self?.levelSmoothing ?? 0.3)
                    self?.audioLevel = smoothed
                }
            }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            audioEngine = nil
            throw AudioRecorderError.engineStartFailed(underlying: error)
        }

        isRecording = true
        logger.info("Recording started (device: \(self.selectedDeviceUID ?? "default", privacy: .public))")
    }

    /// Stop recording and return the captured audio as WAV-formatted `Data`.
    /// Returns `nil` when there is nothing to return (no audio was captured).
    @discardableResult
    func stopRecording() -> Data? {
        guard isRecording, let engine = audioEngine else { return nil }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        audioEngine = nil
        isRecording = false
        audioLevel = 0.0

        logger.info("Recording stopped, buffer count: \(self.pcmBuffers.count)")

        guard !pcmBuffers.isEmpty, let format = recordingFormat else {
            return nil
        }

        let rawPCM = combineBuffers(pcmBuffers)
        pcmBuffers.removeAll()

        guard !rawPCM.isEmpty else { return nil }

        // Convert Float32 PCM to Int16 PCM and wrap in a WAV container.
        let int16Data = float32ToInt16(rawPCM)
        let wav = wavData(from: int16Data, sampleRate: UInt32(format.sampleRate), channels: UInt16(format.channelCount))
        return wav
    }

    // MARK: - Device Selection (CoreAudio HAL)

    /// Point an AVAudioEngine's input node at a specific hardware device.
    private nonisolated func setAudioEngineInputDevice(engine: AVAudioEngine, uid: String) throws {
        // Resolve device ID from UID.
        var deviceID = AudioDeviceID(0)
        var uidCF: CFString = uid as CFString
        var translation = AudioValueTranslation(
            mInputData: &uidCF,
            mInputDataSize: UInt32(MemoryLayout<CFString>.size),
            mOutputData: &deviceID,
            mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        var translationSize = UInt32(MemoryLayout<AudioValueTranslation>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &translationSize,
            &translation
        )
        guard status == noErr, deviceID != 0 else {
            throw AudioRecorderError.deviceSelectionFailed(uid: uid)
        }

        // Set the device on the engine's input node's underlying audio unit.
        let inputNode = engine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            throw AudioRecorderError.inputNodeUnavailable
        }
        var devID = deviceID
        let setStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard setStatus == noErr else {
            throw AudioRecorderError.deviceSelectionFailed(uid: uid)
        }
    }

    // MARK: - Audio Level

    /// Compute the RMS level of a buffer and return a normalised 0...1 value.
    private nonisolated static func rmsLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData, buffer.frameLength > 0 else {
            return 0.0
        }
        let samples = channelData[0]
        let count = Int(buffer.frameLength)

        var sumOfSquares: Float = 0
        for i in 0..<count {
            let sample = samples[i]
            sumOfSquares += sample * sample
        }
        let rms = sqrtf(sumOfSquares / Float(count))

        // Map RMS to a 0...1 range. Speech typically peaks around -12 dB
        // (RMS ~0.25). We use a gentle curve so quiet speech still registers.
        let normalized = min(rms * 5.0, 1.0)
        return normalized
    }

    // MARK: - PCM / WAV Helpers

    private func combineBuffers(_ buffers: [Data]) -> Data {
        var combined = Data()
        combined.reserveCapacity(buffers.reduce(0) { $0 + $1.count })
        for buffer in buffers {
            combined.append(buffer)
        }
        return combined
    }

    /// Convert Float32 sample data to Int16 (little-endian).
    private func float32ToInt16(_ float32Data: Data) -> Data {
        let sampleCount = float32Data.count / MemoryLayout<Float>.size
        var int16Data = Data(capacity: sampleCount * MemoryLayout<Int16>.size)

        float32Data.withUnsafeBytes { rawBuffer in
            guard let floatPointer = rawBuffer.baseAddress?.assumingMemoryBound(to: Float.self) else { return }
            for i in 0..<sampleCount {
                let clamped = max(-1.0, min(1.0, floatPointer[i]))
                var sample = Int16(clamped * Float(Int16.max))
                withUnsafeBytes(of: &sample) { int16Data.append(contentsOf: $0) }
            }
        }
        return int16Data
    }

    /// Build a complete WAV file (RIFF header + PCM 16-bit data).
    private func wavData(from pcmData: Data, sampleRate: UInt32, channels: UInt16) -> Data {
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let chunkSize = 36 + dataSize  // 36 bytes of header fields before data

        var header = Data(capacity: 44)

        // RIFF chunk descriptor
        header.append(contentsOf: "RIFF".utf8)                          // ChunkID
        header.append(littleEndian: chunkSize)                           // ChunkSize
        header.append(contentsOf: "WAVE".utf8)                          // Format

        // "fmt " sub-chunk
        header.append(contentsOf: "fmt ".utf8)                          // Subchunk1ID
        header.append(littleEndian: UInt32(16))                          // Subchunk1Size (PCM)
        header.append(littleEndian: UInt16(1))                           // AudioFormat (1 = PCM)
        header.append(littleEndian: channels)                            // NumChannels
        header.append(littleEndian: sampleRate)                          // SampleRate
        header.append(littleEndian: byteRate)                            // ByteRate
        header.append(littleEndian: blockAlign)                          // BlockAlign
        header.append(littleEndian: bitsPerSample)                       // BitsPerSample

        // "data" sub-chunk
        header.append(contentsOf: "data".utf8)                          // Subchunk2ID
        header.append(littleEndian: dataSize)                            // Subchunk2Size

        var wav = header
        wav.append(pcmData)
        return wav
    }
}

// MARK: - Data + Little Endian Helpers

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func append(littleEndian value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
