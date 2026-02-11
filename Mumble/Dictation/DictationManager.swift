// DictationManager.swift
// Mumble
//
// Central orchestrator for the dictation workflow: monitors the configured
// shortcut, records audio, sends it to the Groq API for transcription,
// optionally transforms the tone, and inserts the result at the cursor position.

import Combine
import Foundation

// MARK: - DictationManager

@MainActor
final class DictationManager: ObservableObject {

    // MARK: - Published State

    /// `true` while audio is being actively recorded (shortcut held down).
    @Published private(set) var isDictating: Bool = false

    /// `true` while the transcription API request is in flight.
    @Published private(set) var isProcessing: Bool = false

    /// Lifetime count of successful transcriptions, persisted across launches.
    @Published var transcriptionCount: Int {
        didSet {
            UserDefaults.standard.set(transcriptionCount, forKey: DictationManager.transcriptionCountKey)
        }
    }

    // MARK: - Debug Access

    /// The raw transcript text from the most recent successful transcription
    /// (before any tone transformation).
    private(set) var lastRawTranscript: String?

    /// The error description from the most recent failed transcription attempt.
    private(set) var lastError: String?

    // MARK: - Dependencies

    let shortcutMonitor: ShortcutMonitor
    private let audioRecorder: AudioRecorder
    private let soundPlayer: SoundPlayer
    private let groqService: GroqTranscriptionService
    private let appContextDetector: AppContextDetector
    private let textInserter: TextInserter
    private let keychainManager: KeychainManager
    private let permissionManager: PermissionManager
    private let toneTransformer: ToneTransformer
    private let llmFormattingService: LLMFormattingService
    private let hud: DictationHUD

    private let logger = STTLogger.shared

    // MARK: - Private State

    /// Combine subscription for forwarding audio level changes to the HUD.
    private var audioLevelCancellable: AnyCancellable?

    /// Tracks whether shortcut monitoring is active.
    private var isMonitoring = false

    private static let transcriptionCountKey = "com.mumble.transcriptionCount"

    // MARK: - Initialisation

    init(
        shortcutMonitor: ShortcutMonitor = ShortcutMonitor(),
        audioRecorder: AudioRecorder? = nil,
        soundPlayer: SoundPlayer? = nil,
        groqService: GroqTranscriptionService = .shared,
        appContextDetector: AppContextDetector = AppContextDetector(),
        textInserter: TextInserter = TextInserter(),
        keychainManager: KeychainManager = .shared,
        permissionManager: PermissionManager? = nil,
        toneTransformer: ToneTransformer = ToneTransformer(),
        llmFormattingService: LLMFormattingService = .shared,
        hud: DictationHUD? = nil
    ) {
        self.shortcutMonitor = shortcutMonitor
        self.audioRecorder = audioRecorder ?? AudioRecorder()
        self.soundPlayer = soundPlayer ?? SoundPlayer()
        self.groqService = groqService
        self.appContextDetector = appContextDetector
        self.textInserter = textInserter
        self.keychainManager = keychainManager
        self.permissionManager = permissionManager ?? PermissionManager()
        self.toneTransformer = toneTransformer
        self.llmFormattingService = llmFormattingService
        self.hud = hud ?? DictationHUD()

        // Restore persisted transcription count.
        self.transcriptionCount = UserDefaults.standard.integer(forKey: DictationManager.transcriptionCountKey)
    }

    deinit {
        audioLevelCancellable?.cancel()
    }

    // MARK: - Public API

    /// Begin monitoring the configured shortcut for press-to-dictate.
    func start() {
        guard !isMonitoring else { return }

        shortcutMonitor.onShortcutDown = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleShortcutDown()
            }
        }

        shortcutMonitor.onShortcutUp = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleShortcutUp()
            }
        }

        shortcutMonitor.startMonitoring()
        isMonitoring = true
        logger.info("DictationManager started")
    }

    /// Stop monitoring the shortcut and cancel any in-progress dictation.
    func stop() {
        guard isMonitoring else { return }

        shortcutMonitor.stopMonitoring()
        shortcutMonitor.onShortcutDown = nil
        shortcutMonitor.onShortcutUp = nil

        // Clean up any in-progress session.
        if isDictating {
            _ = audioRecorder.stopRecording()
            isDictating = false
        }
        hud.hide()
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil

        isMonitoring = false
        logger.info("DictationManager stopped")
    }

    /// Updates the active shortcut binding. The ShortcutMonitor restarts
    /// automatically via its `didSet` observer.
    func updateShortcut(_ binding: ShortcutBinding) {
        shortcutMonitor.shortcut = binding
        logger.info("DictationManager: shortcut updated to \(binding.displayString)")
    }

    // MARK: - Shortcut Handlers

    /// Called when the user activates the shortcut. Validates prerequisites and starts recording.
    private func handleShortcutDown() {
        // Guard: do not start a new session if we are already dictating or processing.
        guard !isDictating, !isProcessing else { return }

        // 1. Check permissions.
        permissionManager.refreshPermissions()

        if !permissionManager.microphoneGranted {
            logger.warning("DictationManager: microphone permission not granted, cannot start dictation")
            hud.show()
            hud.showError("Microphone access required")
            return
        }

        if !permissionManager.accessibilityGranted {
            logger.warning("DictationManager: accessibility permission not granted, cannot start dictation")
            hud.show()
            hud.showError("Accessibility access required")
            return
        }

        // 2. Check API key.
        guard keychainManager.getAPIKey() != nil else {
            logger.warning("DictationManager: no API key configured, cannot start dictation")
            hud.show()
            hud.showError("API key missing")
            return
        }

        // 3. Play start sound.
        soundPlayer.playStartSound()

        // 4. Start audio recording.
        do {
            try audioRecorder.startRecording()
        } catch {
            logger.error("DictationManager: failed to start recording - \(error.localizedDescription)")
            hud.show()
            hud.showError("Recording failed to start")
            return
        }

        // 5. Show HUD.
        hud.show()

        // 6. Forward audio levels to the HUD.
        audioLevelCancellable = audioRecorder.$audioLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] level in
                self?.hud.updateAudioLevel(level)
            }

        // 7. Update state.
        isDictating = true
        lastError = nil
        logger.info("DictationManager: dictation started")
    }

    /// Called when the user releases the shortcut. Stops recording and kicks off
    /// the transcription pipeline.
    private func handleShortcutUp() {
        guard isDictating else { return }

        // 1. Stop recording and retrieve the audio data.
        let audioData = audioRecorder.stopRecording()

        // 1a. Skip transcription if the recording was silent (prevents Whisper hallucinations).
        if audioRecorder.peakAudioLevel < 0.01 {
            audioLevelCancellable?.cancel()
            audioLevelCancellable = nil
            soundPlayer.playEndSound()
            isDictating = false
            logger.info("DictationManager: silent recording, skipping transcription")
            hud.hide()
            return
        }

        // 2. Stop forwarding audio levels.
        audioLevelCancellable?.cancel()
        audioLevelCancellable = nil

        // 3. Play end sound.
        soundPlayer.playEndSound()

        // 4. Update HUD to processing state.
        hud.showProcessing()

        // 5. Update state.
        isDictating = false
        isProcessing = true

        logger.info("DictationManager: recording stopped, beginning transcription pipeline")

        // 6. Hand off to the async transcription pipeline.
        Task { @MainActor in
            await processTranscription(audioData: audioData)
        }
    }

    // MARK: - Transcription Pipeline

    /// Sends audio to the Groq API, applies tone transformation, and inserts
    /// the final text at the cursor position.
    private func processTranscription(audioData: Data?) async {
        defer {
            isProcessing = false
        }

        // Validate audio data.
        guard let audioData, !audioData.isEmpty else {
            logger.warning("DictationManager: no audio data captured")
            hud.showError("No audio captured")
            lastError = "No audio data captured"
            return
        }

        // Retrieve API key (re-check in case it was removed mid-session).
        guard let apiKey = keychainManager.getAPIKey(), !apiKey.isEmpty else {
            logger.error("DictationManager: API key missing during transcription")
            hud.showError("API key not configured")
            lastError = "API key not configured"
            return
        }

        // Detect application context (for tone selection).
        let appContext = appContextDetector.detectFrontmostApp()
        let toneProfile = toneForApp(appContext)

        // Load custom vocabulary config.
        let vocabularyConfig = VocabularyConfig.load()

        logger.debug("DictationManager: app context = \(appContext.appName ?? "Unknown"), tone = \(toneProfile.displayName)")

        do {
            // Send audio to Groq for transcription.
            let rawTranscript = try await groqService.transcribeWithRetry(
                audioData: audioData,
                apiKey: apiKey
            )

            // Store the raw transcript for debug access.
            lastRawTranscript = rawTranscript
            lastError = nil

            guard !rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                logger.warning("DictationManager: transcription returned empty text")
                hud.showError("No speech detected")
                return
            }

            logger.info("DictationManager: transcription received (\(rawTranscript.count) chars)")

            // Apply formatting (LLM-based or rule-based).
            let finalText: String
            if FormattingConfig.isLLMFormattingEnabled {
                finalText = await formatWithLLM(
                    rawTranscript,
                    appContext: appContext,
                    tone: toneProfile,
                    apiKey: apiKey,
                    vocabularySection: vocabularyConfig.llmPromptSection
                )
            } else {
                let toneFormatted = applyToneTransformation(rawTranscript, tone: toneProfile)
                finalText = VocabularyReplacer.apply(vocabularyConfig.validEntries, to: toneFormatted)
            }

            // Insert text at the cursor position.
            textInserter.insertText(finalText)

            // Increment the lifetime transcription counter.
            transcriptionCount += 1

            Analytics.send(.dictationCompleted, parameters: [
                "charCount": String(finalText.count),
                "usedLLMFormatting": String(FormattingConfig.isLLMFormattingEnabled),
                "toneProfile": toneProfile.displayName
            ])

            logger.info("DictationManager: text inserted, total transcriptions = \(transcriptionCount)")

            // Dismiss the HUD.
            hud.hide()

        } catch {
            let errorDescription = (error as? TranscriptionError)?.errorDescription
                ?? error.localizedDescription

            Analytics.send(.transcriptionFailed, parameters: [
                "errorType": String(describing: type(of: error))
            ])

            logger.error("DictationManager: transcription failed - \(errorDescription)")
            lastError = errorDescription
            hud.showError("Transcription failed")
        }
    }

    // MARK: - Tone Transformation

    /// Applies tone transformation to the transcribed text using ToneTransformer.
    private func applyToneTransformation(_ text: String, tone: ToneProfile) -> String {
        toneTransformer.transform(text, tone: tone)
    }

    /// Formats text using the LLM service, falling back to rule-based
    /// ``ToneTransformer`` on any error.
    private func formatWithLLM(
        _ text: String,
        appContext: AppContext,
        tone: ToneProfile,
        apiKey: String,
        vocabularySection: String? = nil
    ) async -> String {
        let category = FormattingCategory.classify(appContext)
        let systemPrompt = category.systemPrompt(for: tone, vocabularySection: vocabularySection)

        logger.info("DictationManager: formatting category = \(category), bundleID = \(appContext.bundleIdentifier ?? "nil"), windowTitle = \(appContext.windowTitle ?? "nil")")

        do {
            let formatted = try await llmFormattingService.format(
                transcript: text,
                systemPrompt: systemPrompt,
                apiKey: apiKey
            )
            logger.info("DictationManager: LLM formatting succeeded (category: \(category))")
            return formatted
        } catch {
            Analytics.send(.llmFormattingFailed, parameters: [
                "errorType": String(describing: type(of: error))
            ])
            logger.warning("DictationManager: LLM formatting failed, falling back to rule-based - \(error.localizedDescription)")
            return applyToneTransformation(text, tone: tone)
        }
    }
}
