// ShortcutSetupView.swift
// Mumble
//
// Onboarding step 3: lets the user see/change their dictation shortcut and
// try it live with real audio transcription.

import SwiftUI
import AppKit

// MARK: - ShortcutSetupView (Step 3 — Shortcut)

struct ShortcutSetupView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 24)

            // Shortcut recorder card
            shortcutCard

            Spacer().frame(height: 16)

            // Try it here card
            tryItHereCard

            Spacer().frame(height: 16)

            // Settings reminder
            settingsReminder
        }
        .onAppear {
            viewModel.startDemoListening()
        }
        .onDisappear {
            viewModel.stopDemoListening()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image("MumbleIconShortcut")
                .resizable()
                .scaledToFit()
                .frame(height: 100)

            Text("Dictation Shortcut")
                .font(.title.bold())

            Text("Hold down the shortcut to start dictating. Release to stop and insert text.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Shortcut Card

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Shortcut")
                    .font(.headline)

                Spacer()

                OnboardingShortcutRecorderView(viewModel: viewModel)
            }

            Button("Reset to Default (Fn)") {
                viewModel.resetShortcutToDefault()
                // Update demo monitor with new shortcut
                viewModel.resumeDemoAfterRecording()
            }
            .disabled(viewModel.currentShortcut == .defaultFnKey)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Try It Here Card

    private var tryItHereCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try It Here")
                .font(.headline)

            Text("Hold **\(viewModel.currentShortcut.displayString)** and speak…")
                .font(.callout)
                .foregroundStyle(.secondary)

            // Transcribed text area
            TextEditor(text: $viewModel.demoText)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 80)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .onChange(of: viewModel.demoText) { _, newValue in
                    if newValue.count > 280 {
                        viewModel.demoText = String(newValue.prefix(280))
                    }
                }

            // Recording / transcribing indicator
            HStack(spacing: 8) {
                if viewModel.isDemoRecording {
                    audioLevelIndicator
                    Text("Recording…")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if viewModel.isDemoTranscribing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Transcribing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Ready")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(height: 16)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Audio Level Indicator

    private var audioLevelIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.red)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 14)
    }

    private func barHeight(for index: Int) -> CGFloat {
        let level = CGFloat(viewModel.demoAudioLevel)
        let threshold = CGFloat(index) * 0.2
        let barLevel = max(0, min(1, (level - threshold) / 0.2))
        return 4 + barLevel * 10
    }

    // MARK: - Settings Reminder

    private var settingsReminder: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text("You can change this later in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - OnboardingShortcutRecorderView

/// Inline shortcut recorder adapted for OnboardingViewModel.
struct OnboardingShortcutRecorderView: View {

    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isRecording = false

    var body: some View {
        Button {
            if isRecording {
                cancelRecording()
            } else {
                startRecording()
            }
        } label: {
            Text(isRecording ? "Press a shortcut…" : viewModel.currentShortcut.displayString)
                .font(.system(.body, design: .rounded).weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecording ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onExitCommand {
            if isRecording { cancelRecording() }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        isRecording = true
        viewModel.pauseDemoForRecording()
        viewModel.startRecordingShortcut {
            isRecording = false
            viewModel.resumeDemoAfterRecording()
        }
    }

    private func cancelRecording() {
        isRecording = false
        viewModel.cancelRecordingShortcut()
        viewModel.resumeDemoAfterRecording()
    }
}

// MARK: - Preview

#Preview {
    ShortcutSetupView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
