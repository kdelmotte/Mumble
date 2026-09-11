// ClipboardConfig.swift
// Mumble
//
// UserDefaults-backed preference for retaining completed transcriptions on the clipboard.

import Foundation

// MARK: - ClipboardConfig

enum ClipboardConfig {

    private static let key = "com.mumble.automaticClipboardCopyEnabled"

    /// Whether Mumble should leave the final formatted transcription on the clipboard
    /// after inserting it. The feature is opt-in and defaults to disabled.
    static var isAutomaticCopyEnabled: Bool {
        get { isAutomaticCopyEnabled(in: .standard) }
        set { setAutomaticCopyEnabled(newValue, in: .standard) }
    }

    static func isAutomaticCopyEnabled(in userDefaults: UserDefaults) -> Bool {
        userDefaults.bool(forKey: key)
    }

    static func setAutomaticCopyEnabled(_ isEnabled: Bool, in userDefaults: UserDefaults) {
        userDefaults.set(isEnabled, forKey: key)
    }
}
