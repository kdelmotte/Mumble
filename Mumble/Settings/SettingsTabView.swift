// SettingsTabView.swift
// Mumble
//
// The "Settings" tab in the Settings sidebar. Contains API key management,
// microphone selection, launch at login, sound configuration, and analytics preferences.

import SwiftUI

struct SettingsTabView: View {

    @ObservedObject var viewModel: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mascot header
                Image("MumbleIconSettings")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 160)
                    .mascotGlow(color: .blue)

                Form {
                    transcriptionSection
                    providerKeysSection
                    formattingSection
                    microphoneSection
                    generalSection
                    soundsSection
                    analyticsSection
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
        .sheet(item: $viewModel.editingProvider) { provider in
            APIKeySheet(viewModel: viewModel, provider: provider)
        }
    }

    // MARK: - Transcription

    private var transcriptionSection: some View {
        Section {
            Picker("Provider", selection: providerBinding) {
                ForEach(TranscriptionProvider.allCases) { provider in
                    Text(provider.displayName)
                        .tag(provider)
                }
            }

            Picker("Model", selection: modelBinding) {
                ForEach(viewModel.availableModels) { model in
                    Text(model.displayName)
                        .tag(model.id)
                }
            }
            .disabled(viewModel.availableModels.count == 1)

            if let detail = viewModel.selectedModel.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if viewModel.maskedAPIKey(for: viewModel.selectedProvider).isEmpty {
                    Text("No \(viewModel.selectedProvider.displayName) key configured")
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.maskedAPIKey(for: viewModel.selectedProvider))
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                let status = viewModel.apiKeyStatus(for: viewModel.selectedProvider)
                Label(status.label, systemImage: status.systemImage)
                    .foregroundStyle(status.tintColor)
                    .font(.callout)
            }

            Button("Update Selected Provider Key...") {
                viewModel.showUpdateKeySheet(for: viewModel.selectedProvider)
            }
        } header: {
            Text("Transcription")
        }
    }

    private var providerKeysSection: some View {
        Section("Provider Keys") {
            ForEach(TranscriptionProvider.allCases) { provider in
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(provider.displayName)

                        if viewModel.maskedAPIKey(for: provider).isEmpty {
                            Text(provider.shortDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(viewModel.maskedAPIKey(for: provider))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    let status = viewModel.apiKeyStatus(for: provider)
                    Label(status.label, systemImage: status.systemImage)
                        .foregroundStyle(status.tintColor)
                        .font(.caption)

                    Button("Update...") {
                        viewModel.showUpdateKeySheet(for: provider)
                    }
                }
            }
        }
    }

    // MARK: - Text Formatting

    private var formattingSection: some View {
        Section {
            Toggle("Smart formatting", isOn: $viewModel.isLLMFormattingEnabled)

            Text("Uses Groq to clean up filler words, fix grammar, handle corrections, and format text based on the app you're typing in.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.isLLMFormattingEnabled {
                Text("Turning this off disables contextual vocabulary corrections. Word pairs become simple global replacements.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !viewModel.hasGroqFormattingKey {
                Text("Smart formatting needs a saved Groq key. Without one, Mumble falls back to local tone formatting even if another transcription provider is selected.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Text Formatting")
        }
    }

    // MARK: - Microphone

    private var microphoneSection: some View {
        Section {
            Picker("Input Device", selection: $viewModel.selectedMicUID) {
                Text("System Default")
                    .tag("")

                ForEach(viewModel.availableDevices, id: \.uid) { device in
                    Text(device.name)
                        .tag(device.uid)
                }
            }
            .onChange(of: viewModel.selectedMicUID) { _, newValue in
                viewModel.selectDevice(uid: newValue)
            }
        } header: {
            HStack {
                Text("Microphone")
                Spacer()
                Button {
                    viewModel.refreshDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Refresh device list")
            }
        }
    }

    // MARK: - General

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: launchAtLoginBinding)

            Toggle(
                "Copy transcriptions to clipboard",
                isOn: $viewModel.isAutomaticClipboardCopyEnabled
            )

            Text("Leaves each completed transcription on your clipboard after inserting it. This replaces existing clipboard contents and may make the text available to clipboard managers or devices using Universal Clipboard.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { viewModel.loginItemManager.isEnabled },
            set: { newValue in
                if newValue {
                    viewModel.loginItemManager.enable()
                } else {
                    viewModel.loginItemManager.disable()
                }
            }
        )
    }

    // MARK: - Sounds

    private var soundsSection: some View {
        Section("Sounds") {
            Toggle("Play dictation sounds", isOn: soundEnabledBinding)

            HStack {
                Text("Volume")
                Slider(
                    value: soundVolumeBinding,
                    in: 0...1,
                    step: 0.05
                )
                .disabled(!viewModel.soundPlayer.isEnabled)
            }
        }
    }

    private var soundEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.soundPlayer.isEnabled },
            set: { viewModel.soundPlayer.isEnabled = $0 }
        )
    }

    private var soundVolumeBinding: Binding<Float> {
        Binding(
            get: { viewModel.soundPlayer.volume },
            set: { viewModel.soundPlayer.volume = $0 }
        )
    }

    // MARK: - Analytics

    private var analyticsSection: some View {
        Section("Analytics") {
            Toggle("Send anonymous usage data", isOn: analyticsEnabled)

            VStack(alignment: .leading, spacing: 4) {
                Text("When enabled, Mumble sends anonymous product analytics about:")
                Text("• App activity and onboarding progress")
                Text("• Feature usage and settings changes")
                Text("• Error categories and reliability signals")
                Text("Your voice audio and transcript content are sent directly to the providers you configure for transcription and optional Groq smart formatting, and are not included in Mumble analytics.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two-way binding that inverts `Analytics.isOptedOut` so the toggle reads
    /// as "enabled = sending data".
    private var analyticsEnabled: Binding<Bool> {
        Binding(
            get: { !Analytics.isOptedOut },
            set: { Analytics.isOptedOut = !$0 }
        )
    }

    private var providerBinding: Binding<TranscriptionProvider> {
        Binding(
            get: { viewModel.selectedProvider },
            set: { viewModel.selectProvider($0) }
        )
    }

    private var modelBinding: Binding<String> {
        Binding(
            get: { viewModel.selectedModel.id },
            set: { viewModel.selectModel($0) }
        )
    }
}

// MARK: - APIKeySheet

struct APIKeySheet: View {

    @ObservedObject var viewModel: SettingsViewModel
    let provider: TranscriptionProvider
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter \(provider.displayName) API Key")
                .font(.mumbleDisplay(size: 18))

            Link(provider.keySetupLabel, destination: provider.keySetupURL)
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)

            SecureField(provider.apiKeyPlaceholder, text: $viewModel.pendingAPIKey)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onSubmit {
                    Task { await viewModel.testAndSaveKey() }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(
                            isFieldFocused
                                ? MumbleTheme.brandGradient
                                : LinearGradient(colors: [Color.clear], startPoint: .leading, endPoint: .trailing),
                            lineWidth: isFieldFocused ? 2 : 0
                        )
                        .animation(.easeInOut(duration: 0.2), value: isFieldFocused)
                )

            if let message = viewModel.alertMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancel") {
                    viewModel.editingProvider = nil
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(MumbleButtonStyle(isProminent: false))

                Spacer()

                Button("Test & Save") {
                    Task { await viewModel.testAndSaveKey() }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(MumbleButtonStyle(isProminent: true))
                .disabled(viewModel.pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTesting)
                .opacity((viewModel.pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTesting) ? 0.5 : 1.0)
            }

            if viewModel.isTesting {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color(red: 0.91, green: 0.45, blue: 0.36))
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear { isFieldFocused = true }
    }
}
