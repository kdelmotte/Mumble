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
                .staggeredEntrance(index: 0)

            Spacer().frame(height: 16)

            // Try it here card
            tryItHereCard
                .staggeredEntrance(index: 1)

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
                .mascotGlow(color: .indigo)

            Text("Dictation Shortcut")
                .font(.mumbleDisplay(size: 28))

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
                    .font(.mumbleHeadline())

                Spacer()

                OnboardingShortcutRecorderView(viewModel: viewModel)
            }

            Button("Reset to Default (Fn)") {
                viewModel.resetShortcutToDefault()
                viewModel.resumeDemoAfterRecording()
            }
            .disabled(viewModel.currentShortcut == .defaultFnKey)
        }
        .themedCard(accent: .indigo)
    }

    // MARK: - Try It Here Card

    private var tryItHereCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try It Here")
                .font(.mumbleHeadline())

            Text("Hold **\(viewModel.currentShortcut.displayString)** and speak…")
                .font(.callout)
                .foregroundStyle(.secondary)

            // Transcribed text area
            TextEditor(text: $viewModel.demoText)
                .font(.body)
                .frame(minHeight: 40, maxHeight: 60)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .topLeading) {
                    if viewModel.demoText.isEmpty {
                        Text("Hey, I'm ready to start mumbling.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            viewModel.isDemoRecording
                                ? AnyShapeStyle(MumbleTheme.brandGradient)
                                : AnyShapeStyle(Color.primary.opacity(0.1)),
                            lineWidth: viewModel.isDemoRecording ? 2 : 1
                        )
                        .animation(.easeInOut(duration: 0.3), value: viewModel.isDemoRecording)
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
        .themedCard(accent: .indigo, elevated: true)
    }

    // MARK: - Audio Level Indicator

    private var audioLevelIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(MumbleTheme.brandGradient)
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
                        .fill(isRecording ? AnyShapeStyle(MumbleTheme.brandGradient.opacity(0.15)) : AnyShapeStyle(Color.secondary.opacity(0.1)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isRecording ? AnyShapeStyle(MumbleTheme.brandGradient) : AnyShapeStyle(Color.secondary.opacity(0.3)), lineWidth: isRecording ? 2 : 1)
                )
                .scaleEffect(isRecording ? 1.03 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
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
