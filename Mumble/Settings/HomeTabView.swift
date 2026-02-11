// HomeTabView.swift
// Mumble
//
// The "Home" tab in the Settings sidebar. Shows the mascot icon,
// app title and tagline, version info, and transcription counter.

import SwiftUI

struct HomeTabView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mascot header
                Image("MumbleIconHome")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)

                // Title + tagline
                VStack(spacing: 6) {
                    Text("Mumble")
                        .font(.largeTitle.weight(.bold))

                    Text("Voice-to-text, your way.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .padding(.horizontal, 40)

                // Info section
                Form {
                    Section {
                        LabeledContent("Version") {
                            Text(viewModel.appVersion)
                                .foregroundStyle(.secondary)
                        }

                        LabeledContent("Transcriptions") {
                            HStack(spacing: 8) {
                                Text("\(viewModel.transcriptionCount)")
                                    .foregroundStyle(.secondary)
                                    .contentTransition(.numericText())

                                Button("Reset") {
                                    viewModel.resetTranscriptionCount()
                                }
                                .font(.callout)
                                .buttonStyle(.borderless)
                            }
                        }
                    }

                    Section {
                        Toggle("Send anonymous usage data", isOn: analyticsEnabled)
                        Text("Helps improve Mumble. No personal data is collected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Analytics Opt-Out Binding

    /// Two-way binding that inverts `Analytics.isOptedOut` so the toggle reads
    /// as "enabled = sending data".
    private var analyticsEnabled: Binding<Bool> {
        Binding(
            get: { !Analytics.isOptedOut },
            set: { Analytics.isOptedOut = !$0 }
        )
    }
}
