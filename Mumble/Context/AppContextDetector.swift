import Foundation
import AppKit

// MARK: - AppContext

/// Describes the user's current application context: which app is in the foreground,
/// and optionally which browser tab is active (inferred from the window title).
struct AppContext: Equatable, Sendable {
    /// The CFBundleIdentifier of the frontmost application, e.g. "com.apple.Safari".
    let bundleIdentifier: String?

    /// The localized display name of the frontmost application, e.g. "Safari".
    let appName: String?

    /// The title of the frontmost window, obtained via Accessibility API.
    /// Used for classification when the frontmost app is a browser.
    let windowTitle: String?
}

// MARK: - AppContextDetector

/// Detects which application is currently in the foreground and, for known browsers,
/// reads the window title via the Accessibility API to infer the active page.
///
/// > Note: Window title retrieval uses the same Accessibility permission that Mumble
/// > already requires for text insertion — no additional permissions are needed.
final class AppContextDetector {

    // MARK: - Public API

    /// Returns the current foreground application context.
    ///
    /// This call is synchronous and fast. For browsers it reads the window title
    /// via the Accessibility API to enable page-level classification.
    func detectFrontmostApp() -> AppContext {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else {
            STTLogger.shared.warning("AppContextDetector: unable to determine frontmost application")
            return AppContext(bundleIdentifier: nil, appName: nil, windowTitle: nil)
        }

        let bundleID = frontmost.bundleIdentifier
        let appName = frontmost.localizedName

        var windowTitle: String?

        if let bundleID, AppRegistry.browserBundleIDs.contains(bundleID) {
            windowTitle = fetchBrowserWindowTitle(pid: frontmost.processIdentifier)
        }

        STTLogger.shared.debug("AppContextDetector: \(appName ?? "Unknown") (\(bundleID ?? "?"))"
                               + (windowTitle.map { " title=\($0)" } ?? ""))

        return AppContext(bundleIdentifier: bundleID, appName: appName, windowTitle: windowTitle)
    }

    // MARK: - Private Helpers

    /// Reads the frontmost window title of the given process using the Accessibility API.
    /// This requires the Accessibility permission that Mumble already requests for text insertion.
    private func fetchBrowserWindowTitle(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)

        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else {
            return nil
        }

        // Force cast is safe: AXUIElement is a CoreFoundation opaque type and
        // the conditional downcast always succeeds (compiler-verified).
        let windowElement = windowValue as! AXUIElement

        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, kAXTitleAttribute as CFString, &titleValue) == .success else {
            return nil
        }

        guard let title = titleValue as? String else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
