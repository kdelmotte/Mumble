// AppRegistry.swift
// Mumble
//
// Single source of truth for known application bundle identifiers and their
// categorisation. Both FormattingContext (email/messaging/code) and
// ToneMappingConfig (personal/work/other) derive from this registry so that
// adding a new app only requires one change.

import Foundation

// MARK: - AppRole

/// The functional role of a known application, used by downstream layers to
/// derive their own category enums.
enum AppRole: Sendable {
    case email
    case messaging
    case code
    case browser
}

// MARK: - AppEntry

/// A single entry in the registry describing a known application.
struct AppEntry: Sendable {
    let bundleID: String
    let role: AppRole

    /// Which ``AppGroup`` this app belongs to for tone selection.
    let toneGroup: AppGroup
}

// MARK: - AppRegistry

enum AppRegistry {

    /// All known applications. Add new apps here and both the formatting
    /// context and tone mapping layers pick them up automatically.
    static let entries: [AppEntry] = [
        // Email
        AppEntry(bundleID: "com.apple.mail",             role: .email,     toneGroup: .work),

        // Messaging
        AppEntry(bundleID: "com.apple.MobileSMS",        role: .messaging, toneGroup: .personal),
        AppEntry(bundleID: "com.hnc.Discord",            role: .messaging, toneGroup: .personal),
        AppEntry(bundleID: "com.tinyspeck.slackmacgap",  role: .messaging, toneGroup: .work),

        // Code editors
        AppEntry(bundleID: "com.microsoft.VSCode",       role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.apple.dt.Xcode",         role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.googlecode.iterm2",      role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.jetbrains.intellij",     role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.jetbrains.pycharm",      role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.jetbrains.WebStorm",     role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.jetbrains.CLion",        role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.jetbrains.goland",       role: .code,      toneGroup: .work),
        AppEntry(bundleID: "com.jetbrains.rider",        role: .code,      toneGroup: .work),

        // Browsers (role: .browser, used by AppContextDetector for window title reading)
        AppEntry(bundleID: "com.apple.Safari",           role: .browser,   toneGroup: .work),
        AppEntry(bundleID: "com.google.Chrome",          role: .browser,   toneGroup: .work),
        AppEntry(bundleID: "company.thebrowser.Browser",  role: .browser,  toneGroup: .work),
        AppEntry(bundleID: "com.microsoft.edgemac",      role: .browser,   toneGroup: .work),
    ]

    // MARK: - Lookup Helpers

    /// All bundle IDs with the given role.
    static func bundleIDs(for role: AppRole) -> Set<String> {
        Set(entries.filter { $0.role == role }.map(\.bundleID))
    }

    /// All bundle IDs that are web browsers.
    static var browserBundleIDs: Set<String> {
        bundleIDs(for: .browser)
    }

    /// All bundle IDs for a given tone group.
    static func bundleIDs(for group: AppGroup) -> Set<String> {
        Set(entries.filter { $0.toneGroup == group }.map(\.bundleID))
    }

    /// Returns the `AppGroup` for a given bundle ID, defaulting to `.other`.
    static func toneGroup(for bundleID: String) -> AppGroup {
        entries.first(where: { $0.bundleID == bundleID })?.toneGroup ?? .other
    }

    /// Returns the `AppRole` for a given bundle ID, or `nil` if unknown.
    static func role(for bundleID: String) -> AppRole? {
        entries.first(where: { $0.bundleID == bundleID })?.role
    }
}
