// SettingsViewModel.swift
// Mumble
//
// Data source for the Settings window. Aggregates state from
// KeychainManager, LoginItemManager, AudioRecorder, SoundPlayer,
// and DictationManager into a single observable object that the
// SwiftUI view can bind to.

import Foundation
import SwiftUI
import Combine
import AppKit

// MARK: - API Key Status

enum APIKeyStatus: Equatable {
    case notSet
    case valid
    case invalid
    case testing

    var label: String {
        switch self {
        case .notSet:  return "Not Set"
        case .valid:   return "Valid"
        case .invalid: return "Invalid"
        case .testing: return "Testing..."
        }
    }

    var systemImage: String {
        switch self {
        case .notSet:  return "xmark.circle"
        case .valid:   return "checkmark.circle.fill"
        case .invalid: return "exclamationmark.triangle.fill"
        case .testing: return "arrow.triangle.2.circlepath"
        }
    }

    var tintColor: Color {
        switch self {
        case .notSet:  return .secondary
        case .valid:   return .green
        case .invalid: return .red
        case .testing: return .orange
        }
    }
}

// MARK: - SettingsViewModel

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Dependencies

    private let keychainManager: KeychainManager
    let loginItemManager: LoginItemManager
    let audioRecorder: AudioRecorder
    let soundPlayer: SoundPlayer
    private let transcriptionService: GroqTranscriptionService

    /// Weak reference avoids a retain cycle when DictationManager also holds
    /// a reference to shared services. The view model only reads from it.
    weak var dictationManager: DictationManager?

    // MARK: - Published State

    /// The masked representation of the stored API key, e.g. "••••••••abcd".
    @Published var maskedAPIKey: String = ""

    /// Current validation status of the stored API key.
    @Published var apiKeyStatus: APIKeyStatus = .notSet

    /// UID of the currently selected microphone. Persisted across launches.
    @AppStorage("selectedMicrophoneUID") var selectedMicUID: String = ""

    /// Available audio input devices as (name, uid) pairs.
    @Published var availableDevices: [(name: String, uid: String)] = []

    /// Temporary key entry in the "Update Key" sheet.
    @Published var pendingAPIKey: String = ""

    /// Controls visibility of the API key update sheet.
    @Published var isShowingKeySheet: Bool = false

    /// User-facing error message shown in alerts or inline.
    @Published var alertMessage: String?

    /// Whether an API key test is currently in flight.
    @Published var isTesting: Bool = false

    // MARK: - Shortcut State

    /// The currently configured dictation shortcut.
    @Published var currentShortcut: ShortcutBinding = .load()

    // MARK: - Formatting State

    /// Whether LLM-based smart formatting is enabled.
    @Published var isLLMFormattingEnabled: Bool = FormattingConfig.isLLMFormattingEnabled {
        didSet { FormattingConfig.isLLMFormattingEnabled = isLLMFormattingEnabled }
    }

    // MARK: - Tone Config State

    /// The user's per-group tone mapping configuration.
    @Published var toneMappingConfig: ToneMappingConfig = .load()

    // MARK: - Shortcut Recording

    private let shortcutRecorder = ShortcutRecorder()

    // MARK: - Init

    init(
        keychainManager: KeychainManager = .shared,
        loginItemManager: LoginItemManager,
        audioRecorder: AudioRecorder,
        soundPlayer: SoundPlayer,
        dictationManager: DictationManager? = nil,
        transcriptionService: GroqTranscriptionService = .shared
    ) {
        self.keychainManager = keychainManager
        self.loginItemManager = loginItemManager
        self.audioRecorder = audioRecorder
        self.soundPlayer = soundPlayer
        self.dictationManager = dictationManager
        self.transcriptionService = transcriptionService

        shortcutRecorder.onRecorded = { [weak self] binding in
            self?.currentShortcut = binding
            self?.dictationManager?.updateShortcut(binding)
        }

        loadMaskedKey()
        refreshDevices()
        applySelectedDevice()
    }

    // MARK: - API Key

    /// Opens the "Update Key" sheet.
    func showUpdateKeySheet() {
        pendingAPIKey = ""
        alertMessage = nil
        isShowingKeySheet = true
    }

    /// Tests the pending key against the Groq API, and if valid, saves it to the Keychain.
    func testAndSaveKey() async {
        let key = pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            alertMessage = "Please enter an API key."
            return
        }

        isTesting = true
        apiKeyStatus = .testing
        alertMessage = nil

        do {
            try await transcriptionService.validateAPIKey(key)

            // Validation succeeded -- persist.
            try keychainManager.saveAPIKey(key)
            loadMaskedKey()
            apiKeyStatus = .valid
            isShowingKeySheet = false
            STTLogger.shared.info("API key updated and validated successfully")
        } catch {
            apiKeyStatus = .invalid
            alertMessage = error.localizedDescription
            STTLogger.shared.warning("API key validation failed: \(error.localizedDescription)")
        }

        isTesting = false
    }

    /// Refreshes the masked key display from the Keychain.
    func loadMaskedKey() {
        if let key = keychainManager.getAPIKey(), !key.isEmpty {
            let suffix = String(key.suffix(4))
            maskedAPIKey = String(repeating: "\u{2022}", count: 8) + suffix
            if apiKeyStatus == .notSet {
                apiKeyStatus = .valid
            }
        } else {
            maskedAPIKey = ""
            apiKeyStatus = .notSet
        }
    }

    // MARK: - Microphone

    /// Re-enumerates available audio input devices.
    func refreshDevices() {
        availableDevices = audioRecorder.availableInputDevices()

        // If the persisted UID no longer exists, fall back to system default.
        if !selectedMicUID.isEmpty,
           !availableDevices.contains(where: { $0.uid == selectedMicUID }) {
            selectedMicUID = ""
        }
    }

    /// Applies the selected device UID to the AudioRecorder.
    func applySelectedDevice() {
        do {
            let uid = selectedMicUID.isEmpty ? nil : selectedMicUID
            try audioRecorder.selectInputDevice(uid: uid)
        } catch {
            STTLogger.shared.warning("Failed to select microphone: \(error.localizedDescription)")
            alertMessage = error.localizedDescription
        }
    }

    /// Called when the user picks a new device in the dropdown.
    func selectDevice(uid: String) {
        selectedMicUID = uid
        applySelectedDevice()
    }

    // MARK: - Transcription Count

    /// The total number of transcriptions performed, sourced from DictationManager.
    var transcriptionCount: Int {
        dictationManager?.transcriptionCount ?? 0
    }

    /// Resets the lifetime transcription counter to zero.
    func resetTranscriptionCount() {
        dictationManager?.transcriptionCount = 0
        objectWillChange.send()
    }

    // MARK: - App Version

    /// The human-readable app version string, e.g. "1.0 (42)".
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "–"
        return "\(version) (\(build))"
    }

    // MARK: - Shortcut Recording

    func startRecordingShortcut(completion: @escaping () -> Void) {
        shortcutRecorder.startRecording(completion: completion)
    }

    func cancelRecordingShortcut() {
        shortcutRecorder.cancelRecording()
    }

    func resetShortcutToDefault() {
        ShortcutBinding.resetToDefault()
        currentShortcut = .defaultFnKey
        dictationManager?.updateShortcut(.defaultFnKey)
    }

    // MARK: - Tone Config

    /// Returns a two-way `Binding<ToneProfile>` for the given app group
    /// that auto-saves changes to UserDefaults.
    func toneBinding(for group: AppGroup) -> Binding<ToneProfile> {
        ToneMappingConfig.toneBinding(
            for: group,
            get: { [weak self] in self?.toneMappingConfig },
            set: { [weak self] newTone, group in
                self?.toneMappingConfig.setTone(newTone, for: group)
                self?.toneMappingConfig.save()
            }
        )
    }

}
