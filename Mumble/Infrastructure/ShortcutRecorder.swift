// ShortcutRecorder.swift
// Mumble
//
// Shared shortcut-recording logic used by both SettingsViewModel and
// OnboardingViewModel. Installs temporary local event monitors for
// `.flagsChanged` and `.keyDown`, captures the shortcut, then calls back.

import AppKit

// MARK: - ShortcutRecorder

@MainActor
final class ShortcutRecorder {

    // MARK: - Callbacks

    /// Called when a new shortcut has been successfully recorded.
    /// Receives the captured `ShortcutBinding`.
    var onRecorded: ((ShortcutBinding) -> Void)?

    /// Called when recording is cancelled (e.g. user pressed Escape).
    var onCancelled: (() -> Void)?

    // MARK: - State

    /// Active local event monitors installed during shortcut recording.
    private var monitors: [Any] = []

    /// Completion callback for when recording finishes or is cancelled.
    private var completion: (() -> Void)?

    /// Tracks the peak modifier flags seen during a modifier-only recording.
    private var peakModifierFlags: NSEvent.ModifierFlags = []

    /// Whether a key-down event occurred during the current recording session.
    private var sawKeyDown = false

    // MARK: - Public API

    /// Begins listening for a new shortcut. Installs temporary local monitors
    /// for `.flagsChanged` and `.keyDown`. Calls `completion` when the
    /// recording finishes (either via capture or cancellation).
    func startRecording(completion: @escaping () -> Void) {
        removeMonitors()
        self.completion = completion
        peakModifierFlags = []
        sawKeyDown = false

        if let flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlagsChanged(event)
            return nil
        }) {
            monitors.append(flagsMonitor)
        }

        if let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            self?.handleKeyDown(event)
            return nil
        }) {
            monitors.append(keyMonitor)
        }
    }

    /// Cancels an in-progress shortcut recording.
    func cancelRecording() {
        removeMonitors()
        let cb = completion
        completion = nil
        onCancelled?()
        cb?()
    }

    // MARK: - Event Handlers

    private func handleFlagsChanged(_ event: NSEvent) {
        let flags = event.modifierFlags
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        let current = flags.intersection(relevantFlags)

        if !current.isEmpty {
            peakModifierFlags = peakModifierFlags.union(current)
        } else if !peakModifierFlags.isEmpty && !sawKeyDown {
            let binding = ShortcutBinding(
                modifierFlagsRaw: peakModifierFlags.rawValue,
                keyCode: nil
            )
            finalize(binding)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            cancelRecording()
            return
        }

        sawKeyDown = true

        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        let modifiers = event.modifierFlags.intersection(relevantFlags)

        // Reject bare-key shortcuts (e.g. just "D") to avoid accidental
        // activation while typing in normal apps.
        guard !modifiers.isEmpty else { return }

        let binding = ShortcutBinding(
            modifierFlagsRaw: modifiers.rawValue,
            keyCode: event.keyCode
        )
        finalize(binding)
    }

    private func finalize(_ binding: ShortcutBinding) {
        removeMonitors()
        binding.save()
        onRecorded?(binding)

        let cb = completion
        completion = nil
        cb?()
    }

    private func removeMonitors() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
    }
}
