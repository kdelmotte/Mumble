// ToneSetupView.swift
// Mumble
//
// Onboarding step 4: lets the user configure the tone profile for each
// app group (Personal, Work, Other).

import SwiftUI

// MARK: - ToneSetupView (Step 4)

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
                .frame(height: 80)
                .mascotGlow(color: .teal)

            Text("Tone Behavior")
                .font(.mumbleDisplay(size: 28))

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

        }
        .formStyle(.grouped)
        .scrollDisabled(true)
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
