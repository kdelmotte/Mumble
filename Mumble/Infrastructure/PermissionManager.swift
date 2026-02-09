import Foundation
import AVFoundation
import Combine
import AppKit

// MARK: - PermissionManager

@MainActor
final class PermissionManager: ObservableObject {

    @Published private(set) var microphoneGranted: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false

    private var accessibilityTimer: Timer?
    private let accessibilityCheckInterval: TimeInterval = 2.0

    init() {
        refreshPermissions()
        startAccessibilityPolling()
    }

    deinit {
        accessibilityTimer?.invalidate()
    }

    // MARK: - Refresh All Permissions

    /// Re-checks the current state of all managed permissions.
    func refreshPermissions() {
        checkMicrophonePermission()
        checkAccessibilityPermission()
    }

    // MARK: - Microphone

    /// Requests microphone access. The published property updates once the
    /// user responds to the system prompt (or immediately if access was previously determined).
    func requestMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.microphoneGranted = granted
                    // Short delay lets the TCC dialog fully dismiss before we
                    // try to re-activate. Without this, the accessory app's
                    // windows may not come back to the foreground.
                    try? await Task.sleep(for: .milliseconds(300))
                    NSApp.activate(ignoringOtherApps: true)
                    // Bring the onboarding window to front specifically.
                    for window in NSApp.windows where window.isVisible && window.canBecomeKey {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
        case .denied, .restricted:
            microphoneGranted = false
        @unknown default:
            microphoneGranted = false
        }
    }

    /// Opens System Settings to the Microphone privacy pane.
    func openMicrophoneSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Accessibility

    /// Checks whether Accessibility access has been granted.
    /// This call is non-prompting; it simply reads the current trust state.
    func checkAccessibilityPermission() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    /// Prompts the user to grant Accessibility access by showing the system dialog.
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        accessibilityGranted = trusted
        // Re-activate after a short delay so the app window comes back
        // to the foreground when the user returns from System Settings.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Opens System Settings to the Accessibility privacy pane.
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Private Helpers

    private func checkMicrophonePermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = (status == .authorized)
    }

    /// Accessibility can be toggled externally in System Settings at any time, so we poll
    /// periodically to keep the published property accurate.
    private func startAccessibilityPolling() {
        accessibilityTimer = Timer.scheduledTimer(withTimeInterval: accessibilityCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkAccessibilityPermission()
            }
        }
    }
}
