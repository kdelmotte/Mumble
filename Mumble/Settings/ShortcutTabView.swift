// ShortcutTabView.swift
// Mumble
//
// The "Shortcut" tab in the Settings sidebar. Displays the current dictation
// shortcut and provides a recorder to capture a new one.

import SwiftUI
import AppKit

struct ShortcutTabView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mascot header
                Image("MumbleIconShortcut")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)

                VStack(spacing: 6) {
                    Text("Dictation Shortcut")
                        .font(.title2.weight(.semibold))

                    Text("Hold down the shortcut to start dictating. Release to stop and insert text.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Form {
                    Section {
                        HStack {
                            Text("Current Shortcut")

                            Spacer()

                            ShortcutRecorderView(viewModel: viewModel)
                        }

                        Button("Reset to Default (Fn)") {
                            viewModel.resetShortcutToDefault()
                        }
                        .disabled(viewModel.currentShortcut == .defaultFnKey)
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - ShortcutRecorderView

/// An inline button that enters recording mode on click. Captures the next
/// key/modifier combination and saves it as the new dictation shortcut.
struct ShortcutRecorderView: View {

    @ObservedObject var viewModel: SettingsViewModel
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
        viewModel.startRecordingShortcut { [self] in
            isRecording = false
        }
    }

    private func cancelRecording() {
        isRecording = false
        viewModel.cancelRecordingShortcut()
    }
}
