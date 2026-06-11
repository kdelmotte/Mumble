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

// MARK: - History Access

@MainActor
protocol TranscriptionHistoryManaging: AnyObject {
    var historyRevisionPublisher: AnyPublisher<Int, Never> { get }
    func loadRecentTranscriptions(limit: Int) -> [TranscriptionHistoryEntry]
    func countRecentTranscriptions() -> Int
    func deleteRecentTranscription(id: TranscriptionHistoryEntry.ID)
    func clearRecentTranscriptions()
}

extension DictationManager: TranscriptionHistoryManaging {
    var historyRevisionPublisher: AnyPublisher<Int, Never> {
        $historyRevision.eraseToAnyPublisher()
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
    private let historyManager: TranscriptionHistoryManaging?
    private let historyPageSize: Int

    /// Weak reference avoids a retain cycle when DictationManager also holds
    /// a reference to shared services. The view model only reads from it.
    weak var dictationManager: DictationManager?

    // MARK: - Published State

    @Published var transcriptionConfig: TranscriptionProviderConfig = .load()

    @Published private var maskedAPIKeys: [TranscriptionProvider: String] = [:]
    @Published private var apiKeyStatuses: [TranscriptionProvider: APIKeyStatus] = [:]

    /// UID of the currently selected microphone. Persisted across launches.
    @AppStorage("selectedMicrophoneUID") var selectedMicUID: String = ""

    /// Available audio input devices as (name, uid) pairs.
    @Published var availableDevices: [(name: String, uid: String)] = []

    /// Temporary key entry in the "Update Key" sheet.
    @Published var pendingAPIKey: String = ""

    /// The provider currently being edited in the API key sheet.
    @Published var editingProvider: TranscriptionProvider?

    /// User-facing error message shown in alerts or inline.
    @Published var alertMessage: String?

    /// Whether an API key test is currently in flight.
    @Published var isTesting: Bool = false

    /// The total number of completed transcriptions.
    @Published private(set) var transcriptionCount: Int = 0

    /// The currently loaded page of transcription history entries.
    @Published private(set) var historyEntries: [TranscriptionHistoryEntry] = []

    /// The total number of retained history entries.
    @Published private(set) var historyTotalCount: Int = 0

    /// Whether there are more retained entries than are currently loaded.
    @Published private(set) var hasMoreHistory: Bool = false

    /// `true` while the History tab is refreshing its current page.
    @Published private(set) var isLoadingHistory: Bool = false

    /// The current History tab page size.
    @Published private(set) var visibleHistoryLimit: Int = 0

    // MARK: - Shortcut State

    /// The currently configured dictation shortcut.
    @Published var currentShortcut: ShortcutBinding = .load()

    // MARK: - Formatting State

    /// Whether LLM-based smart formatting is enabled.
    @Published var isLLMFormattingEnabled: Bool = FormattingConfig.isLLMFormattingEnabled {
        didSet {
            FormattingConfig.isLLMFormattingEnabled = isLLMFormattingEnabled
            Analytics.send(.llmFormattingToggled, parameters: [
                "enabled": String(isLLMFormattingEnabled)
            ])
        }
    }

    // MARK: - Tone Config State

    /// The user's per-group tone mapping configuration.
    @Published var toneMappingConfig: ToneMappingConfig = .load()

    // MARK: - Vocabulary Config State

    /// The user's custom vocabulary (spoken→corrected word pairs).
    @Published var vocabularyConfig: VocabularyConfig = .load()

    // MARK: - Shortcut Recording

    private let shortcutRecorder = ShortcutRecorder()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        keychainManager: KeychainManager = .shared,
        loginItemManager: LoginItemManager,
        audioRecorder: AudioRecorder,
        soundPlayer: SoundPlayer,
        dictationManager: DictationManager? = nil,
        historyManager: TranscriptionHistoryManaging? = nil,
        historyPageSize: Int = 50,
        loadPersistedAPIKeysOnInit: Bool = true
    ) {
        self.keychainManager = keychainManager
        self.loginItemManager = loginItemManager
        self.audioRecorder = audioRecorder
        self.soundPlayer = soundPlayer
        self.dictationManager = dictationManager
        self.historyManager = historyManager ?? dictationManager
        self.historyPageSize = max(1, historyPageSize)

        shortcutRecorder.onRecorded = { [weak self] binding in
            self?.currentShortcut = binding
            self?.dictationManager?.updateShortcut(binding)
        }

        if loadPersistedAPIKeysOnInit {
            loadMaskedKeys()
        }
        refreshDevices()
        applySelectedDevice()
        bindDictationState()
        bindHistoryState()
    }

    // MARK: - API Key

    var selectedProvider: TranscriptionProvider {
        transcriptionConfig.selectedProvider
    }

    var selectedModel: TranscriptionModelOption {
        transcriptionConfig.selectedModel(for: selectedProvider)
    }

    var availableModels: [TranscriptionModelOption] {
        selectedProvider.models
    }

    var hasGroqFormattingKey: Bool {
        !(keychainManager.getAPIKey(for: .groq)?.isEmpty ?? true)
    }

    func maskedAPIKey(for provider: TranscriptionProvider) -> String {
        maskedAPIKeys[provider] ?? ""
    }

    func apiKeyStatus(for provider: TranscriptionProvider) -> APIKeyStatus {
        apiKeyStatuses[provider] ?? .notSet
    }

    /// Opens the "Update Key" sheet.
    func showUpdateKeySheet(for provider: TranscriptionProvider) {
        pendingAPIKey = ""
        alertMessage = nil
        editingProvider = provider
    }

    func selectProvider(_ provider: TranscriptionProvider) {
        guard provider != selectedProvider else { return }

        var config = transcriptionConfig
        config.selectedProvider = provider
        transcriptionConfig = config
        transcriptionConfig.save()
    }

    func selectModel(_ modelID: String) {
        guard modelID != selectedModel.id else { return }

        var config = transcriptionConfig
        config.selectModel(modelID, for: selectedProvider)
        transcriptionConfig = config
        transcriptionConfig.save()
    }

    /// Tests the pending key against the selected provider, and if valid, saves it to the Keychain.
    func testAndSaveKey() async {
        guard let provider = editingProvider else { return }

        let key = pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            alertMessage = "Please enter an API key."
            return
        }

        isTesting = true
        setAPIKeyStatus(.testing, for: provider)
        alertMessage = nil

        do {
            let service = TranscriptionServiceFactory.service(for: provider)
            let model = transcriptionConfig.selectedModel(for: provider)
            try await service.validateAPIKey(key, model: model)

            // Validation succeeded -- persist.
            try keychainManager.saveAPIKey(key, for: provider)
            loadMaskedKeys()
            setAPIKeyStatus(.valid, for: provider)
            editingProvider = nil
            STTLogger.shared.info("\(provider.displayName) API key updated and validated successfully")
        } catch {
            setAPIKeyStatus(.invalid, for: provider)
            alertMessage = error.localizedDescription
            STTLogger.shared.warning("API key validation failed: \(error.localizedDescription)")
        }

        isTesting = false
    }

    /// Refreshes the masked key display from the Keychain.
    func loadMaskedKeys() {
        for provider in TranscriptionProvider.allCases {
            if let key = keychainManager.getAPIKey(for: provider), !key.isEmpty {
                let suffix = String(key.suffix(4))
                setMaskedAPIKey(String(repeating: "\u{2022}", count: 8) + suffix, for: provider)
                if apiKeyStatus(for: provider) == .notSet {
                    setAPIKeyStatus(.valid, for: provider)
                }
            } else {
                setMaskedAPIKey("", for: provider)
                setAPIKeyStatus(.notSet, for: provider)
            }
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

    // MARK: - Transcription History

    /// Resets the lifetime transcription counter to zero.
    func resetTranscriptionCount() {
        transcriptionCount = 0
        dictationManager?.transcriptionCount = 0
    }

    func copyRecentTranscription(_ entry: TranscriptionHistoryEntry) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(entry.text, forType: .string)
    }

    func deleteRecentTranscription(id: TranscriptionHistoryEntry.ID) {
        historyManager?.deleteRecentTranscription(id: id)
    }

    func clearRecentTranscriptions() {
        historyManager?.clearRecentTranscriptions()
    }

    func loadInitialHistoryIfNeeded() {
        guard visibleHistoryLimit == 0 else { return }
        loadInitialHistory()
    }

    func loadInitialHistory() {
        visibleHistoryLimit = historyPageSize
        reloadVisibleHistory()
    }

    func loadMoreHistory() {
        guard hasMoreHistory, !isLoadingHistory else { return }
        visibleHistoryLimit += historyPageSize
        reloadVisibleHistory()
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

    // MARK: - Vocabulary Config

    /// Appends a new empty vocabulary entry.
    func addVocabularyEntry() {
        vocabularyConfig.entries.append(VocabularyEntry())
    }

    /// Removes a vocabulary entry by its ID.
    func removeVocabularyEntry(id: UUID) {
        vocabularyConfig.entries.removeAll { $0.id == id }
    }

    /// Persists the current vocabulary config to UserDefaults.
    func saveVocabularyConfig() {
        vocabularyConfig.save()
    }

    // MARK: - Private Helpers

    private func bindDictationState() {
        transcriptionCount = dictationManager?.transcriptionCount ?? 0

        guard let dictationManager else { return }

        dictationManager.$transcriptionCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.transcriptionCount = count
            }
            .store(in: &cancellables)
    }

    private func bindHistoryState() {
        historyManager?.historyRevisionPublisher
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.visibleHistoryLimit > 0 else { return }
                self.reloadVisibleHistory()
            }
            .store(in: &cancellables)
    }

    private func reloadVisibleHistory() {
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        guard let historyManager, visibleHistoryLimit > 0 else {
            historyEntries = []
            historyTotalCount = 0
            hasMoreHistory = false
            return
        }

        let entries = historyManager.loadRecentTranscriptions(limit: visibleHistoryLimit)
        let totalCount = historyManager.countRecentTranscriptions()

        historyEntries = entries
        historyTotalCount = totalCount
        hasMoreHistory = entries.count < totalCount
    }

    private func setMaskedAPIKey(_ value: String, for provider: TranscriptionProvider) {
        var copy = maskedAPIKeys
        copy[provider] = value
        maskedAPIKeys = copy
    }

    private func setAPIKeyStatus(_ status: APIKeyStatus, for provider: TranscriptionProvider) {
        var copy = apiKeyStatuses
        copy[provider] = status
        apiKeyStatuses = copy
    }

}
