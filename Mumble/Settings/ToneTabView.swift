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
                    .mascotGlow(color: .teal)

                VStack(spacing: 6) {
                    Text("Tone Behavior")
                        .font(.mumbleDisplay(size: 22))

                    Text("Choose how Mumble formats your speech for different types of apps.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Form {
                    Section {
                        ForEach(AppGroup.allCases) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                Picker(group.displayName, selection: viewModel.toneBinding(for: group)) {
                                    ForEach(ToneProfile.allCases, id: \.self) { tone in
                                        Text(tone.displayName).tag(tone)
                                    }
                                }
                                .help(group.appDescription)

                                // Tone preview
                                Text(tonePreviewText(for: viewModel.toneMappingConfig.tone(for: group)))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.teal.opacity(0.04))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
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

    // MARK: - Tone Preview Text

    private func tonePreviewText(for tone: ToneProfile) -> String {
        switch tone {
        case .professional:
            return "\"I would like to schedule a meeting for tomorrow afternoon.\""
        case .casual:
            return "\"I'd like to schedule a meeting for tomorrow afternoon.\""
        case .veryCasual:
            return "\"wanna schedule a meeting for tomorrow afternoon\""
        }
    }
}
