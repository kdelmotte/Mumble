// Analytics.swift
// Mumble
//
// Thin wrapper around TelemetryDeck for privacy-first analytics.
// All signals are anonymous — no IP addresses, no PII, no fingerprinting.

import Foundation
import TelemetryDeck

// MARK: - Analytics

enum Analytics {

    // MARK: - Configuration

    private static let appID = "3A57C131-FE7B-4D45-94FD-A31150CBAFD6"
    private static let optOutKey = "com.mumble.analyticsOptOut"

    /// Tracks the last onboarding step viewed, so `Onboarding.abandoned` can
    /// report it even without a reference to the view model.
    static var lastOnboardingStepSeen: Int = 0

    /// Whether the user has opted out of anonymous analytics.
    static var isOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optOutKey) }
        set { UserDefaults.standard.set(newValue, forKey: optOutKey) }
    }

    /// Initialise TelemetryDeck. Call once at app launch.
    static func configure() {
        let config = TelemetryDeck.Config(appID: appID)
        TelemetryDeck.initialize(config: config)
    }

    /// Send an analytics signal if the user hasn't opted out.
    static func send(_ event: Event, parameters: [String: String] = [:]) {
        guard !isOptedOut else { return }
        TelemetryDeck.signal(event.rawValue, parameters: parameters)
    }

    // MARK: - Event Constants

    enum Event: String {
        // Activation
        case appLaunched              = "App.launched"
        case onboardingStepViewed     = "Onboarding.stepViewed"
        case onboardingCompleted      = "Onboarding.completed"
        case onboardingAbandoned      = "Onboarding.abandoned"

        // Engagement
        case dictationCompleted       = "Dictation.completed"
        case llmFormattingToggled     = "Feature.llmFormattingToggled"
        case settingsOpened           = "Settings.opened"

        // Errors
        case transcriptionFailed      = "Error.transcriptionFailed"
        case llmFormattingFailed      = "Error.llmFormattingFailed"
    }
}
