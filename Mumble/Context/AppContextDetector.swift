import Foundation
import AppKit

// MARK: - AppContext

/// Describes the user's current application context: which app is in the foreground,
/// and optionally which URL is active (for browsers).
struct AppContext: Equatable, Sendable {
    /// The CFBundleIdentifier of the frontmost application, e.g. "com.apple.Safari".
    let bundleIdentifier: String?

    /// The localized display name of the frontmost application, e.g. "Safari".
    let appName: String?

    /// The URL of the active browser tab, if the frontmost app is a known browser and
    /// the AppleScript query succeeds. `nil` for non-browser apps or when the query fails.
    let url: String?
}

// MARK: - Known Bundle Identifiers

private enum KnownBundleID {
    static let safari   = "com.apple.Safari"
    static let chrome   = "com.google.Chrome"
    static let arc      = "company.thebrowser.Browser"
    static let edge     = "com.microsoft.edgemac"
    static let messages = "com.apple.MobileSMS"
    static let mail     = "com.apple.mail"
    static let slack    = "com.tinyspeck.slackmacgap"
    static let discord  = "com.hnc.Discord"

    /// All bundle identifiers that correspond to web browsers.
    static let browsers: Set<String> = [safari, chrome, arc, edge]
}

// MARK: - AppContextDetector

/// Detects which application is currently in the foreground and, for known browsers,
/// attempts to retrieve the active tab's URL via AppleScript.
///
/// > Note: Browser URL retrieval requires the user to have granted Automation (or
/// > Accessibility) permissions. If the AppleScript call fails for any reason the
/// > detector gracefully returns `nil` for the URL.
final class AppContextDetector {

    // MARK: - Public API

    /// Returns the current foreground application context.
    ///
    /// This call is synchronous and fast for non-browser apps. For browsers it may take
    /// a small amount of time to execute an AppleScript query.
    func detectFrontmostApp() -> AppContext {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            STTLogger.shared.warning("AppContextDetector: unable to determine frontmost application")
            return AppContext(bundleIdentifier: nil, appName: nil, url: nil)
        }

        let bundleID = frontmost.bundleIdentifier
        let appName = frontmost.localizedName

        var url: String?

        if let bundleID, KnownBundleID.browsers.contains(bundleID) {
            url = fetchBrowserURL(bundleIdentifier: bundleID)
        }

        STTLogger.shared.debug("AppContextDetector: \(appName ?? "Unknown") (\(bundleID ?? "?"))"
                               + (url.map { " url=\($0)" } ?? ""))

        return AppContext(bundleIdentifier: bundleID, appName: appName, url: url)
    }

    // MARK: - Private Helpers

    /// Executes an AppleScript snippet tailored to the given browser and returns the
    /// active tab's URL, or `nil` if the script fails.
    private func fetchBrowserURL(bundleIdentifier: String) -> String? {
        let script: String

        switch bundleIdentifier {
        case KnownBundleID.safari:
            script = """
            tell application "Safari"
                if (count of windows) > 0 then
                    return URL of current tab of front window
                end if
            end tell
            """

        case KnownBundleID.chrome:
            script = """
            tell application "Google Chrome"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """

        case KnownBundleID.arc:
            script = """
            tell application "Arc"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """

        case KnownBundleID.edge:
            script = """
            tell application "Microsoft Edge"
                if (count of windows) > 0 then
                    return URL of active tab of front window
                end if
            end tell
            """

        default:
            return nil
        }

        return executeAppleScript(script)
    }

    /// Runs an AppleScript source string and returns the result as a trimmed `String`,
    /// or `nil` on any error.
    private func executeAppleScript(_ source: String) -> String? {
        let appleScript = NSAppleScript(source: source)
        var errorInfo: NSDictionary?
        let result = appleScript?.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "unknown"
            STTLogger.shared.debug("AppContextDetector: AppleScript error - \(message)")
            return nil
        }

        guard let stringValue = result?.stringValue else {
            return nil
        }

        let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
