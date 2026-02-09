// SoundPlayer.swift
// Mumble
//
// Plays short audible cues when dictation starts and stops.
// Prefers bundled sound files ("dictation_start.aif", "dictation_end.aif")
// and falls back to programmatically generated tones when those assets are
// missing from the app bundle.

import AVFoundation
import Combine
import os.log

// MARK: - SoundPlayer

@MainActor
final class SoundPlayer: ObservableObject {

    // MARK: Published State

    /// Playback volume for dictation sounds (0.0 ... 1.0).
    @Published var volume: Float = 0.7

    /// When `false`, all playback is silenced.
    @Published var isEnabled: Bool = true

    // MARK: Private Properties

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.mumble", category: "SoundPlayer")

    /// Cached WAV data for the start tone (generated lazily).
    private var startSoundData: Data?

    /// Cached WAV data for the end tone (generated lazily).
    private var endSoundData: Data?

    /// A dedicated audio player so we can set volume and avoid blocking.
    private var player: AVAudioPlayer?

    // MARK: - Initialisation

    init() {
        // Eagerly generate fallback tones so first playback isn't delayed.
        prepareSounds()
    }

    // MARK: - Public API

    /// Play the "recording started" sound.
    func playStartSound() {
        guard isEnabled else { return }
        play(data: startSoundData)
    }

    /// Play the "recording stopped" sound.
    func playEndSound() {
        guard isEnabled else { return }
        play(data: endSoundData)
    }

    // MARK: - Sound Preparation

    private func prepareSounds() {
        startSoundData = loadBundleSound(named: "dictation_start")
            ?? generateStartTone()

        endSoundData = loadBundleSound(named: "dictation_end")
            ?? generateEndTone()
    }

    /// Attempt to load a sound file from the main bundle.
    /// Supports .aif, .aiff, .wav, .mp3, .m4a.
    private func loadBundleSound(named name: String) -> Data? {
        let extensions = ["aif", "aiff", "wav", "mp3", "m4a", "caf"]
        for ext in extensions {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    let data = try Data(contentsOf: url)
                    logger.info("Loaded bundle sound: \(name).\(ext)")
                    return data
                } catch {
                    logger.warning("Found \(name).\(ext) but failed to read: \(error.localizedDescription)")
                }
            }
        }
        return nil
    }

    // MARK: - Playback

    private func play(data: Data?) {
        guard let data else {
            logger.warning("No sound data available for playback.")
            return
        }

        do {
            let audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer.volume = volume
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            // Keep a strong reference until playback finishes.
            self.player = audioPlayer
        } catch {
            logger.error("Sound playback failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Programmatic Tone Generation

    /// Start sound: ascending "boop" -- 880 Hz sine for 0.1 s, with a
    /// fast envelope to avoid clicks.
    private func generateStartTone() -> Data {
        logger.info("Generating fallback start tone (880 Hz, 0.1 s)")
        return generateToneSequence(segments: [
            ToneSegment(frequency: 880, duration: 0.1)
        ])
    }

    /// End sound: descending "boop-boop" -- 440 Hz for 0.08 s then 330 Hz
    /// for 0.08 s, separated by a tiny 15 ms silence.
    private func generateEndTone() -> Data {
        logger.info("Generating fallback end tone (440 Hz + 330 Hz)")
        return generateToneSequence(segments: [
            ToneSegment(frequency: 440, duration: 0.08),
            ToneSegment(frequency: 0, duration: 0.015),   // brief silence
            ToneSegment(frequency: 330, duration: 0.08)
        ])
    }

    // MARK: - Tone Synthesis Helpers

    private struct ToneSegment {
        let frequency: Double   // Hz, 0 = silence
        let duration: Double    // seconds
    }

    /// Render one or more `ToneSegment`s into 16-bit mono WAV data at 44.1 kHz.
    private func generateToneSequence(segments: [ToneSegment]) -> Data {
        let sampleRate: Double = 44_100
        let amplitude: Double = 0.45  // keep headroom; volume knob scales further

        // Envelope ramp duration to avoid click artefacts.
        let rampDuration: Double = 0.005 // 5 ms

        var samples: [Int16] = []

        for segment in segments {
            let frameCount = Int(segment.duration * sampleRate)
            let rampFrames = Int(rampDuration * sampleRate)

            for i in 0..<frameCount {
                var value: Double
                if segment.frequency > 0 {
                    let phase = 2.0 * Double.pi * segment.frequency * Double(i) / sampleRate
                    value = sin(phase) * amplitude
                } else {
                    value = 0.0
                }

                // Apply fade-in / fade-out envelope.
                if i < rampFrames {
                    let envelope = Double(i) / Double(rampFrames)
                    value *= envelope
                } else if i > frameCount - rampFrames {
                    let remaining = Double(frameCount - i) / Double(rampFrames)
                    value *= remaining
                }

                let clamped = max(-1.0, min(1.0, value))
                samples.append(Int16(clamped * Double(Int16.max)))
            }
        }

        return wavFromInt16Samples(samples, sampleRate: UInt32(sampleRate), channels: 1)
    }

    /// Wrap raw Int16 PCM samples into a minimal WAV container.
    private func wavFromInt16Samples(_ samples: [Int16], sampleRate: UInt32, channels: UInt16) -> Data {
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        let chunkSize: UInt32 = 36 + dataSize

        var data = Data(capacity: 44 + Int(dataSize))

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.appendLE(chunkSize)
        data.append(contentsOf: "WAVE".utf8)

        // fmt sub-chunk
        data.append(contentsOf: "fmt ".utf8)
        data.appendLE(UInt32(16))       // sub-chunk size
        data.appendLE(UInt16(1))        // PCM format
        data.appendLE(channels)
        data.appendLE(sampleRate)
        data.appendLE(byteRate)
        data.appendLE(blockAlign)
        data.appendLE(bitsPerSample)

        // data sub-chunk
        data.append(contentsOf: "data".utf8)
        data.appendLE(dataSize)

        // Sample data
        for sample in samples {
            data.appendLE(sample)
        }

        return data
    }
}

// MARK: - Data + Little-Endian Append Helpers (private to this file)

private extension Data {
    mutating func appendLE(_ value: UInt16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: UInt32) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }

    mutating func appendLE(_ value: Int16) {
        var v = value.littleEndian
        Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) }
    }
}
