// ToneSetupView.swift
// Mumble
//
// Onboarding step 3: lets the user configure the tone profile for each
// app group (Personal, Work, Other).

import SwiftUI

// MARK: - ToneSetupView (Step 3)

struct ToneSetupView: View {

    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Spacer().frame(height: 24)

            // Tone pickers
            tonePickersSection

            Spacer().frame(height: 16)

            // Settings reminder
            settingsReminder
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            Image("MumbleIconTone")
                .resizable()
                .scaledToFit()
                .frame(height: 100)

            Text("Tone Behavior")
                .font(.title.bold())

            Text("Choose how Mumble formats your speech for different types of apps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Tone Pickers

    private var tonePickersSection: some View {
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

// MARK: - Preview

#Preview {
    ToneSetupView(viewModel: OnboardingViewModel())
        .frame(width: 440, height: 500)
        .padding()
}
