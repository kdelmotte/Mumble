// ToneMappingConfig.swift
// Mumble
//
// Stores the user's chosen ToneProfile for each app group (Personal, Work,
// Other). Persisted via UserDefaults as JSON.

import Foundation
import SwiftUI

// MARK: - AppGroup

/// Categorises applications into high-level groups for tone selection.
enum AppGroup: String, CaseIterable, Codable, Identifiable {

    case personal
    case work
    case other

    var id: String { rawValue }

    /// The bundle identifiers that belong to this group, derived from ``AppRegistry``.
    var bundleIDs: Set<String> {
        AppRegistry.bundleIDs(for: self)
    }

    /// User-facing name shown in the settings UI.
    var displayName: String {
        switch self {
        case .personal: return "Personal"
        case .work:     return "Work"
        case .other:    return "Other"
        }
    }

    /// Descriptive list of representative apps for this group.
    var appDescription: String {
        switch self {
        case .personal: return "Messages, Discord"
        case .work:     return "Mail, Slack, Browsers"
        case .other:    return "All other apps"
        }
    }

    /// Returns the `AppGroup` that a given bundle identifier belongs to,
    /// falling back to `.other` if not found.
    static func group(for bundleID: String) -> AppGroup {
        AppRegistry.toneGroup(for: bundleID)
    }
}

// MARK: - ToneMappingConfig

/// Stores the user's chosen `ToneProfile` for each `AppGroup`.
struct ToneMappingConfig: Codable, Equatable {

    var personal: ToneProfile
    var work: ToneProfile
    var other: ToneProfile

    /// Default configuration matching the original hardcoded behaviour.
    static let `default` = ToneMappingConfig(
        personal: .veryCasual,
        work: .casual,
        other: .casual
    )

    /// Returns the tone profile for the given app group.
    func tone(for group: AppGroup) -> ToneProfile {
        switch group {
        case .personal: return personal
        case .work:     return work
        case .other:    return other
        }
    }

    /// Sets the tone profile for the given app group.
    mutating func setTone(_ tone: ToneProfile, for group: AppGroup) {
        switch group {
        case .personal: personal = tone
        case .work:     work = tone
        case .other:    other = tone
        }
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "com.mumble.toneMappingConfig"

    /// Loads the persisted config, falling back to `.default`.
    static func load() -> ToneMappingConfig {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(ToneMappingConfig.self, from: data)
        else {
            return .default
        }
        return config
    }

    /// Persists this config to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: ToneMappingConfig.userDefaultsKey)
        }
    }

    /// Returns a two-way `Binding<ToneProfile>` for the given app group
    /// that auto-saves changes to UserDefaults. Both SettingsViewModel and
    /// OnboardingViewModel call this shared factory.
    static func toneBinding(
        for group: AppGroup,
        get configGetter: @escaping () -> ToneMappingConfig?,
        set configSetter: @escaping (ToneProfile, AppGroup) -> Void
    ) -> Binding<ToneProfile> {
        Binding(
            get: { configGetter()?.tone(for: group) ?? .casual },
            set: { configSetter($0, group) }
        )
    }
}
