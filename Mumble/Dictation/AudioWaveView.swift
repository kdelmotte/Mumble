// AudioWaveView.swift
// Mumble
//
// Animated audio waveform visualization for the dictation HUD.
// Shows responsive bars during recording and a frozen/greyed state
// with a spinner while the transcription API processes audio.

import SwiftUI

// MARK: - AudioWaveView

struct AudioWaveView: View {

    @Binding var audioLevel: Float
    let isRecording: Bool
    let isProcessing: Bool

    /// Number of vertical bars in the waveform.
    private let barCount = 7

    /// Per-bar phase offsets so each bar has a slightly different height at any
    /// given audio level, giving the waveform its organic feel.
    private let phaseOffsets: [Double] = [0.0, 0.6, 0.3, 0.8, 0.15, 0.55, 0.9]

    /// A continuously updating seed that adds subtle motion even at a constant
    /// audio level. Driven by a timer inside the view.
    @State private var animationSeed: Double = 0.0

    /// Timer that drives the animation seed while recording.
    @State private var animationTimer: Timer?

    // MARK: - Body

    var body: some View {
        HStack(spacing: 3) {
            waveformBars

            if isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
                    .transition(.opacity)
            }
        }
        .frame(height: 40)
        .onAppear {
            if isRecording {
                startAnimationTimer()
            }
        }
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                startAnimationTimer()
            } else {
                stopAnimationTimer()
            }
        }
        .onDisappear {
            stopAnimationTimer()
        }
    }

    // MARK: - Waveform Bars

    private var waveformBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                Capsule()
                    .fill(barGradient(for: index))
                    .frame(width: 4, height: barHeight(for: index))
                    .animation(
                        isRecording
                            ? .spring(response: 0.25, dampingFraction: 0.6, blendDuration: 0.1)
                            : .easeOut(duration: 0.3),
                        value: barHeight(for: index)
                    )
            }
        }
    }

    // MARK: - Bar Height Calculation

    /// Computes the height for a bar at the given index.
    ///
    /// When recording, the height is driven by `audioLevel` combined with a
    /// per-bar phase offset and the continuously changing animation seed to
    /// create organic, slightly different heights across bars.
    ///
    /// When processing, all bars freeze at a medium height.
    /// When idle, all bars sit at the minimum height.
    private func barHeight(for index: Int) -> CGFloat {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 32

        if isProcessing {
            // Frozen at roughly half height for a "paused" look.
            let frozenFraction = 0.35 + phaseOffsets[index] * 0.15
            return minHeight + (maxHeight - minHeight) * frozenFraction
        }

        guard isRecording else {
            return minHeight
        }

        // Base contribution from the audio level.
        let level = pow(CGFloat(audioLevel), 0.45)

        // Per-bar variation: scales with audio level so bars are still when
        // quiet and jitter organically when loud.
        let phase = phaseOffsets[index]
        let seed = animationSeed
        let variation = sin((seed + phase) * .pi * 2) * 0.2 * level

        // Combine: level drives the height, variation adds organic movement.
        let fraction = min(max(level + variation, 0.02), 1.0)

        return minHeight + (maxHeight - minHeight) * fraction
    }

    // MARK: - Bar Gradient

    private func barGradient(for index: Int) -> LinearGradient {
        if isProcessing {
            return LinearGradient(
                colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.3)],
                startPoint: .bottom,
                endPoint: .top
            )
        }

        return LinearGradient(
            colors: [Color.cyan, Color.blue],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    // MARK: - Animation Timer

    /// Starts a timer that increments `animationSeed` at ~30 fps to keep the
    /// bars subtly moving even when the audio level is relatively constant.
    private func startAnimationTimer() {
        stopAnimationTimer()
        animationSeed = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor in
                animationSeed += 0.03
            }
        }
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
}

// MARK: - Preview

#if DEBUG
struct AudioWaveView_Preview: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AudioWaveView(
                audioLevel: .constant(0.0),
                isRecording: false,
                isProcessing: false
            )
            .background(Color.black.opacity(0.8))
            .previewDisplayName("Idle")

            AudioWaveView(
                audioLevel: .constant(0.6),
                isRecording: true,
                isProcessing: false
            )
            .background(Color.black.opacity(0.8))
            .previewDisplayName("Recording")

            AudioWaveView(
                audioLevel: .constant(0.0),
                isRecording: false,
                isProcessing: true
            )
            .background(Color.black.opacity(0.8))
            .previewDisplayName("Processing")
        }
        .padding()
    }
}
#endif
