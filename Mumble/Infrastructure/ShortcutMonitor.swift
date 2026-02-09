// ShortcutMonitor.swift
// Mumble
//
// Monitors for a configurable keyboard shortcut (modifier-only like Fn, or
// modifier+key like ⌘D) and fires callbacks on press/release. Replaces the
// previous FnKeyMonitor with generalised shortcut support.

import Foundation
import AppKit

// MARK: - ShortcutMonitor

final class ShortcutMonitor {

    /// Called when the configured shortcut is activated (key/modifier pressed).
    var onShortcutDown: (() -> Void)?

    /// Called when the configured shortcut is deactivated (key/modifier released).
    var onShortcutUp: (() -> Void)?

    /// The shortcut to monitor. Changing this while monitoring is active
    /// automatically restarts the monitors.
    var shortcut: ShortcutBinding {
        didSet {
            guard shortcut != oldValue, isMonitoring else { return }
            stopMonitoring()
            startMonitoring()
        }
    }

    private var globalMonitors: [Any] = []
    private var localMonitors: [Any] = []

    /// Tracks whether the shortcut is currently considered "held".
    private var isDown = false

    /// Whether monitoring is currently active.
    private var isMonitoring = false

    /// Modifier flags that are NOT part of the configured shortcut.
    /// Used for modifier-only shortcuts to reject combos.
    private static let allCheckableModifiers: NSEvent.ModifierFlags = [
        .command, .option, .control, .shift, .capsLock, .function
    ]

    // MARK: - Init

    init(shortcut: ShortcutBinding = .load()) {
        self.shortcut = shortcut
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public API

    func startMonitoring() {
        guard !isMonitoring else { return }

        if shortcut.keyCode == nil {
            // Modifier-only shortcut (e.g. Fn).
            installModifierOnlyMonitors()
        } else {
            // Modifier+key shortcut (e.g. ⌘D).
            installModifierKeyMonitors()
        }

        isMonitoring = true
        STTLogger.shared.debug("ShortcutMonitor started for \(shortcut.displayString)")
    }

    func stopMonitoring() {
        for monitor in globalMonitors + localMonitors {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitors.removeAll()
        localMonitors.removeAll()
        isDown = false
        isMonitoring = false
        STTLogger.shared.debug("ShortcutMonitor stopped")
    }

    // MARK: - Modifier-Only Monitoring (e.g. Fn)

    private func installModifierOnlyMonitors() {
        let requiredFlags = shortcut.modifierFlags

        // Determine which other modifiers should NOT be present.
        let otherModifiers = Self.allCheckableModifiers.subtracting(requiredFlags)

        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handleModifierOnly(event, requiredFlags: requiredFlags, otherModifiers: otherModifiers)
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) {
            globalMonitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handler(event)
            return event
        }) {
            localMonitors.append(local)
        }
    }

    private func handleModifierOnly(
        _ event: NSEvent,
        requiredFlags: NSEvent.ModifierFlags,
        otherModifiers: NSEvent.ModifierFlags
    ) {
        let flags = event.modifierFlags
        let requiredActive = flags.contains(requiredFlags)
        let hasUnwantedModifiers = !flags.intersection(otherModifiers).isEmpty

        if requiredActive && !isDown {
            isDown = true
            if !hasUnwantedModifiers {
                onShortcutDown?()
            }
        } else if !requiredActive && isDown {
            isDown = false
            if !hasUnwantedModifiers {
                onShortcutUp?()
            }
        }
    }

    // MARK: - Modifier+Key Monitoring (e.g. ⌘D)

    private func installModifierKeyMonitors() {
        let keyDownHandler: (NSEvent) -> Void = { [weak self] event in
            self?.handleKeyDown(event)
        }

        let keyUpHandler: (NSEvent) -> Void = { [weak self] event in
            self?.handleKeyUp(event)
        }

        // Global monitors (app not focused).
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: keyDownHandler) {
            globalMonitors.append(global)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: keyUpHandler) {
            globalMonitors.append(global)
        }

        // Local monitors (app focused).
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            keyDownHandler(event)
            return event
        }) {
            localMonitors.append(local)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { event in
            keyUpHandler(event)
            return event
        }) {
            localMonitors.append(local)
        }
    }

    private func handleKeyDown(_ event: NSEvent) {
        guard !isDown,
              let requiredKeyCode = shortcut.keyCode,
              event.keyCode == requiredKeyCode,
              modifiersMatch(event.modifierFlags)
        else { return }

        isDown = true
        onShortcutDown?()
    }

    private func handleKeyUp(_ event: NSEvent) {
        guard isDown,
              let requiredKeyCode = shortcut.keyCode,
              event.keyCode == requiredKeyCode
        else { return }

        isDown = false
        onShortcutUp?()
    }

    /// Checks that the event's modifier flags contain the required modifiers
    /// from the shortcut (ignoring device-independent bits like numericPad, etc.).
    private func modifiersMatch(_ eventFlags: NSEvent.ModifierFlags) -> Bool {
        let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        let required = shortcut.modifierFlags.intersection(mask)
        let actual = eventFlags.intersection(mask)
        return actual.contains(required)
    }
}
