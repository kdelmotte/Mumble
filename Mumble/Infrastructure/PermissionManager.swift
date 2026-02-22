import Foundation
import AVFoundation
import Combine
import AppKit

// MARK: - PermissionManager

@MainActor
final class PermissionManager: ObservableObject {

    private enum MicrophoneAuthorizationState: CustomStringConvertible {
        case authorized
        case notDetermined
        case denied
        case restricted

        var description: String {
            switch self {
            case .authorized: return "authorized"
            case .notDetermined: return "notDetermined"
            case .denied: return "denied"
            case .restricted: return "restricted"
            }
        }
    }

    @Published private(set) var microphoneGranted: Bool = false
    @Published private(set) var accessibilityGranted: Bool = false

    private let logger = STTLogger.shared

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
        let status = microphoneAuthorizationStatus()
        logger.info("PermissionManager: request microphone permission (status: \(status))")

        switch status {
        case .authorized:
            microphoneGranted = true
        case .notDetermined:
            bringAppWindowsToFront()
            requestMicrophoneAccess { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.microphoneGranted = granted
                    if !granted {
                        self?.openMicrophoneSettings()
                    }
                    // Short delay lets the TCC dialog fully dismiss before we
                    // try to re-activate. Without this, the accessory app's
                    // windows may not come back to the foreground.
                    try? await Task.sleep(for: .milliseconds(300))
                    self?.bringAppWindowsToFront()
                }
            }
        case .denied, .restricted:
            microphoneGranted = false
            // If user previously denied, "Grant" should take them somewhere useful.
            openMicrophoneSettings()
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

    /// Opens System Settings directly to the Accessibility pane, skipping the TCC modal.
    func requestAccessibilityPermission() {
        openAccessibilitySettings()
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
        microphoneGranted = (microphoneAuthorizationStatus() == .authorized)
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

    private func bringAppWindowsToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.isVisible && window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func microphoneAuthorizationStatus() -> MicrophoneAuthorizationState {
        if #available(macOS 14.0, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .authorized
            case .denied:
                return .denied
            case .undetermined:
                // Cross-check with AVFoundation status for compatibility with
                // AVAudioEngine + capture-device based workflows.
                switch AVCaptureDevice.authorizationStatus(for: .audio) {
                case .authorized: return .authorized
                case .notDetermined: return .notDetermined
                case .denied: return .denied
                case .restricted: return .restricted
                @unknown default: return .denied
                }
            @unknown default:
                return .denied
            }
        }

        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    private func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        if #available(macOS 14.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                // Some machines still surface capture-device permission state.
                // If permission remains undetermined, retry through AVCapture.
                if granted {
                    completion(true)
                    return
                }

                if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined {
                    AVCaptureDevice.requestAccess(for: .audio) { captureGranted in
                        completion(captureGranted)
                    }
                } else {
                    completion(false)
                }
            }
            return
        }

        AVCaptureDevice.requestAccess(for: .audio) { granted in
            completion(granted)
        }
    }
}
