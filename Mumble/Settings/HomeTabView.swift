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
                    .mascotGlow(color: .blue)

                // Title + tagline
                VStack(spacing: 6) {
                    Text("Mumble")
                        .font(.mumbleDisplay(size: 32))

                    Text("Voice-to-text, your way.")
                        .font(.mumbleHeadline(size: 16, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                GradientDivider()
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
                        if viewModel.recentTranscriptions.isEmpty {
                            Text("Your last five completed transcriptions will appear here so you can recover text if paste fails.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(viewModel.recentTranscriptions) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .center) {
                                        Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Button("Copy") {
                                            viewModel.copyRecentTranscription(entry)
                                        }
                                        .font(.callout)
                                        .buttonStyle(.borderless)

                                        Button("Delete") {
                                            viewModel.deleteRecentTranscription(id: entry.id)
                                        }
                                        .font(.callout)
                                        .buttonStyle(.borderless)
                                    }

                                    Text(entry.text)
                                        .font(.callout)
                                        .textSelection(.enabled)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    } header: {
                        HStack {
                            Text("Recent Transcriptions")
                            Spacer()

                            if !viewModel.recentTranscriptions.isEmpty {
                                Button("Clear All") {
                                    viewModel.clearRecentTranscriptions()
                                }
                                .font(.callout)
                                .buttonStyle(.borderless)
                            }
                        }
                    } footer: {
                        Text("Stored locally on this Mac only. Keeps the latest five completed transcriptions.")
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
    }
}
