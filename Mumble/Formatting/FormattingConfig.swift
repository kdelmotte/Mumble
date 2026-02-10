// FormattingConfig.swift
// Mumble
//
// UserDefaults-backed toggle for LLM-based smart formatting.
// Defaults to enabled so new users get the best experience out of the box.

import Foundation

// MARK: - FormattingConfig

struct FormattingConfig {

    private static let key = "com.mumble.llmFormattingEnabled"

    /// Whether LLM-based smart formatting is enabled. When disabled, the app
    /// falls back to the rule-based ``ToneTransformer``.
    static var isLLMFormattingEnabled: Bool {
        get {
            // Default to true if the key has never been set.
            if UserDefaults.standard.object(forKey: key) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
