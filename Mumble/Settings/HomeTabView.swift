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
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
    }
}
