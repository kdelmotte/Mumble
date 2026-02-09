import Foundation
import AppKit
import Combine

// MARK: - Key Test Result

enum KeyTestResult: Equatable {
    case success
    case failure(String)

    static func == (lhs: KeyTestResult, rhs: KeyTestResult) -> Bool {
        switch (lhs, rhs) {
        case (.success, .success):
            return true
        case (.failure(let a), .failure(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - OnboardingViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentStep: Int = 0
    @Published var apiKey: String = ""
    @Published var isTestingKey: Bool = false
    @Published var keyTestResult: KeyTestResult?
    @Published var launchAtLogin: Bool = true

    // MARK: - Dependencies

    let permissionManager: PermissionManager
    let keychainManager: KeychainManager
    let loginItemManager: LoginItemManager

    private let transcriptionService: GroqTranscriptionService
    private let logger = STTLogger.shared
    private var permissionCancellable: AnyCancellable?
    private var apiKeyCancellable: AnyCancellable?
    private var validationTask: Task<Void, Never>?

    static let totalSteps = 4

    // MARK: - Init

    init(
        permissionManager: PermissionManager? = nil,
        keychainManager: KeychainManager = .shared,
        loginItemManager: LoginItemManager = LoginItemManager(),
        transcriptionService: GroqTranscriptionService = .shared
    ) {
        self.permissionManager = permissionManager ?? PermissionManager()
        self.keychainManager = keychainManager
        self.loginItemManager = loginItemManager
        self.transcriptionService = transcriptionService

        // Forward PermissionManager changes so SwiftUI views that observe
        // this view model also re-render when permissions change.
        self.permissionCancellable = self.permissionManager.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }

        // Auto-validate API key with debounce
        self.apiKeyCancellable = $apiKey
            .dropFirst()
            .removeDuplicates()
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleAPIKeyChange()
            }
    }

    // MARK: - Navigation

    var canGoBack: Bool {
        currentStep > 0
    }

    var canGoForward: Bool {
        currentStep < OnboardingViewModel.totalSteps - 1
    }

    var isLastStep: Bool {
        currentStep == OnboardingViewModel.totalSteps - 1
    }

    func goToNextStep() {
        guard canGoForward else { return }
        currentStep += 1
    }

    func goToPreviousStep() {
        guard canGoBack else { return }
        currentStep -= 1
    }

    // MARK: - Step Validation

    func canProceedFromStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            // Permissions step: both permissions required to continue
            return permissionManager.microphoneGranted && permissionManager.accessibilityGranted
        case 1:
            // API key step: require successful key test
            return keyTestResult == .success
        case 2:
            // Startup preferences: always allowed
            return true
        case 3:
            // Complete: always allowed
            return true
        default:
            return false
        }
    }

    // MARK: - Permissions

    func requestMicPermission() {
        permissionManager.requestMicrophonePermission()
    }

    func requestAccessibilityPermission() {
        permissionManager.requestAccessibilityPermission()
    }

    // MARK: - API Key

    private func hasValidKeyFormat(_ key: String) -> Bool {
        key.hasPrefix("gsk_") && key.count >= 20
    }

    private func handleAPIKeyChange() {
        validationTask?.cancel()
        validationTask = nil
        keyTestResult = nil
        isTestingKey = false

        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return }

        if !trimmed.hasPrefix("gsk_") && trimmed.count >= 4 {
            keyTestResult = .failure("Groq API keys start with gsk_")
            return
        }

        guard hasValidKeyFormat(trimmed) else { return }

        isTestingKey = true
        validationTask = Task {
            await performValidation(trimmed)
        }
    }

    private func performValidation(_ key: String) async {
        do {
            try await transcriptionService.validateAPIKey(key)
            guard !Task.isCancelled else { return }
            keyTestResult = .success
            saveAPIKey()
            logger.info("API key validated and saved during onboarding")
        } catch let error as TranscriptionError {
            guard !Task.isCancelled else { return }
            switch error {
            case .invalidAPIKey:
                keyTestResult = .failure("Invalid API key. Please check and try again.")
            case .networkError:
                keyTestResult = .failure("Network error. Please check your connection.")
            case .timeout:
                keyTestResult = .failure("Request timed out. Please try again.")
            case .rateLimited:
                keyTestResult = .failure("Rate limited. Please wait a moment and try again.")
            default:
                keyTestResult = .failure(error.localizedDescription)
            }
            logger.warning("API key validation failed during onboarding: \(error.localizedDescription)")
        } catch {
            guard !Task.isCancelled else { return }
            keyTestResult = .failure("An unexpected error occurred.")
            logger.error("Unexpected error validating API key: \(error.localizedDescription)")
        }

        guard !Task.isCancelled else { return }
        isTestingKey = false
    }

    func testAPIKey() async {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            keyTestResult = .failure("Please enter an API key.")
            return
        }

        isTestingKey = true
        keyTestResult = nil
        await performValidation(trimmedKey)
    }

    func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { return }

        do {
            try keychainManager.saveAPIKey(trimmedKey)
        } catch {
            logger.error("Failed to save API key during onboarding: \(error.localizedDescription)")
        }
    }

    // MARK: - Complete Onboarding

    func completeOnboarding() {
        // Apply launch-at-login preference
        if launchAtLogin {
            loginItemManager.enable()
        } else {
            loginItemManager.disable()
        }

        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

        // Notify the app (AppDelegate and OnboardingContainerView listen for this)
        NotificationCenter.default.post(name: .onboardingDidComplete, object: nil)

        logger.info("Onboarding completed successfully")
    }

    // MARK: - Helpers

    /// Whether at least one permission is missing, used to show a warning on the permissions step.
    var hasPermissionWarning: Bool {
        !permissionManager.microphoneGranted || !permissionManager.accessibilityGranted
    }

}
