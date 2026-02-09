// SettingsTabView.swift
// Mumble
//
// The "Settings" tab in the Settings sidebar. Contains API key management,
// microphone selection, launch at login, and sound configuration.

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

                Form {
                    apiKeySection
                    microphoneSection
                    generalSection
                    soundsSection
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $viewModel.isShowingKeySheet) {
            APIKeySheet(viewModel: viewModel)
        }
    }

    // MARK: - API Key

    private var apiKeySection: some View {
        Section {
            HStack {
                if viewModel.maskedAPIKey.isEmpty {
                    Text("No key configured")
                        .foregroundStyle(.secondary)
                } else {
                    Text(viewModel.maskedAPIKey)
                        .font(.system(.body, design: .monospaced))
                }

                Spacer()

                Label(viewModel.apiKeyStatus.label, systemImage: viewModel.apiKeyStatus.systemImage)
                    .foregroundStyle(viewModel.apiKeyStatus.tintColor)
                    .font(.callout)
            }

            Button("Update Key...") {
                viewModel.showUpdateKeySheet()
            }
        } header: {
            Text("Groq API Key")
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
}

// MARK: - APIKeySheet

struct APIKeySheet: View {

    @ObservedObject var viewModel: SettingsViewModel
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            Text("Enter Groq API Key")
                .font(.headline)

            SecureField("gsk_...", text: $viewModel.pendingAPIKey)
                .textFieldStyle(.roundedBorder)
                .focused($isFieldFocused)
                .onSubmit {
                    Task { await viewModel.testAndSaveKey() }
                }

            if let message = viewModel.alertMessage {
                Label(message, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancel") {
                    viewModel.isShowingKeySheet = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Test & Save") {
                    Task { await viewModel.testAndSaveKey() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTesting)
            }

            if viewModel.isTesting {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(24)
        .frame(width: 380)
        .onAppear { isFieldFocused = true }
    }
}
