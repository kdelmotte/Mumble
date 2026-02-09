// ToneTabView.swift
// Mumble
//
// The "Tone" tab in the Settings sidebar. Lets the user configure the
// tone profile used for each app group (Personal, Work, Other).

import SwiftUI

struct ToneTabView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mascot header
                Image("MumbleIconTone")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)

                VStack(spacing: 6) {
                    Text("Tone Behavior")
                        .font(.title2.weight(.semibold))

                    Text("Choose how Mumble formats your speech for different types of apps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Form {
                    Section {
                        ForEach(AppGroup.allCases) { group in
                            Picker(group.displayName, selection: viewModel.toneBinding(for: group)) {
                                ForEach(ToneProfile.allCases, id: \.self) { tone in
                                    Text(tone.displayName).tag(tone)
                                }
                            }
                            .help(group.appDescription)
                        }
                    } header: {
                        Text("Tone Per App Group")
                    } footer: {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(AppGroup.allCases) { group in
                                Text("**\(group.displayName)**: \(group.appDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How tones work")
                                .font(.callout.weight(.medium))

                            Text("**Professional** expands contractions and uses formal punctuation — suitable for emails and documents.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("**Casual** uses proper capitalization and punctuation, keeping your text natural and conversational.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("**Very Casual** uses lowercase and lighter punctuation — like texting a friend.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
    }
}
