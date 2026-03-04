// HistoryTabView.swift
// Mumble
//
// The dedicated "History" tab in Settings. Shows the last 7 days of
// completed transcriptions so the user can recover, copy, or delete them.

import SwiftUI

struct HistoryTabView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                GradientDivider()
                    .padding(.horizontal, 40)

                Form {
                    historySection
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
        .onAppear {
            viewModel.refreshRecentTranscriptions()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image("MumbleIconHistory")
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .mascotGlow(color: .blue)

            Text("History")
                .font(.mumbleDisplay(size: 32))

            Text("Recover missed dictations from the last 7 days.")
                .font(.mumbleHeadline(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var historySection: some View {
        Section {
            if viewModel.recentTranscriptions.isEmpty {
                Text("Completed transcriptions from the last 7 days will appear here so you can recover text if paste fails.")
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
            Text("Stored locally on this Mac only. Keeps completed transcriptions from the last 7 days and automatically removes older entries.")
        }
    }
}
