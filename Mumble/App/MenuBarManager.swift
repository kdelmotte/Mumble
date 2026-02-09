// MenuBarManager.swift
// Mumble
//
// Manages the persistent NSStatusItem in the macOS menu bar.
// Renders an SF Symbol icon as a template image (adapts to light/dark mode),
// builds the dropdown menu, and provides methods for other subsystems to
// update the displayed status (idle, recording, transcribing).

import AppKit
import SwiftUI
import Combine

// MARK: - MenuBarStatus

/// The current operational state displayed in the menu bar dropdown.
enum MenuBarStatus {
    case idle
    case recording
    case transcribing

    var label: String {
        switch self {
        case .idle:          return "Ready"
        case .recording:     return "Recording..."
        case .transcribing:  return "Transcribing..."
        }
    }

    /// SF Symbol name used to tint the status item while active.
    var iconName: String {
        switch self {
        case .idle:          return "waveform"
        case .recording:     return "waveform.circle.fill"
        case .transcribing:  return "ellipsis.circle"
        }
    }
}

// MARK: - MenuBarManager

@MainActor
final class MenuBarManager: NSObject {

    // MARK: - Properties

    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
    private var cancellables = Set<AnyCancellable>()

    /// The current operational status shown in the dropdown.
    private(set) var status: MenuBarStatus = .idle

    /// External callback invoked when the user selects "Settings...".
    var onOpenSettings: (() -> Void)?

    /// Weak reference to a DictationManager to read the transcription count.
    weak var dictationManager: DictationManager?

    // MARK: - Setup

    /// Creates the status item and installs the dropdown menu. Call once at app launch.
    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = statusBarImage(for: .idle)
            button.image?.isTemplate = true
            button.toolTip = "Mumble"
        }

        self.statusItem = item
        rebuildMenu()
    }

    /// Tears down the status item. Call if you need to remove the icon from the bar.
    func tearDown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItem = nil
        menu = nil
    }

    // MARK: - Status Updates

    /// Updates the operational status displayed in the menu bar icon and dropdown.
    func updateStatus(_ newStatus: MenuBarStatus) {
        status = newStatus

        if let button = statusItem?.button {
            button.image = statusBarImage(for: newStatus)
            button.image?.isTemplate = true
        }

        rebuildMenu()
    }

    // MARK: - Menu Construction

    /// Rebuilds the dropdown menu to reflect current state. Called automatically when
    /// status or dictation state changes.
    func rebuildMenu() {
        let newMenu = NSMenu()

        // --- Title + transcription count ---
        let titleItem = NSMenuItem(title: "Mumble", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false

        let count = dictationManager?.transcriptionCount ?? 0
        let subtitleItem = NSMenuItem(
            title: count == 1 ? "1 transcription" : "\(count) transcriptions",
            action: nil,
            keyEquivalent: ""
        )
        subtitleItem.isEnabled = false
        subtitleItem.indentationLevel = 1

        newMenu.addItem(titleItem)
        newMenu.addItem(subtitleItem)
        newMenu.addItem(.separator())

        // --- Settings ---
        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        newMenu.addItem(settingsItem)

        // --- About ---
        let aboutItem = NSMenuItem(
            title: "About Mumble",
            action: #selector(openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        newMenu.addItem(aboutItem)

        newMenu.addItem(.separator())

        // --- Quit ---
        let quitItem = NSMenuItem(
            title: "Quit Mumble",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        newMenu.addItem(quitItem)

        self.menu = newMenu
        statusItem?.menu = newMenu
    }

    // MARK: - Menu Actions

    @objc private func openSettingsAction() {
        onOpenSettings?()
    }

    @objc private func openAboutAction() {
        NSApp.activate(ignoringOtherApps: true)
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationIcon: NSApp.applicationIconImage as Any
        ]
        NSApp.orderFrontStandardAboutPanel(options: options)
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    // MARK: - Icon Rendering

    /// Renders an SF Symbol into an appropriately-sized NSImage for the status bar.
    private func statusBarImage(for status: MenuBarStatus) -> NSImage? {
        let symbolName = status.iconName
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)

        guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Mumble") else {
            STTLogger.shared.warning("MenuBarManager: SF Symbol '\(symbolName)' not found, using fallback")
            return NSImage(systemSymbolName: "waveform", accessibilityDescription: "Mumble")
        }

        return image.withSymbolConfiguration(config)
    }
}
