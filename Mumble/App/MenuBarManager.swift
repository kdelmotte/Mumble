// MenuBarManager.swift
// Mumble
//
// Manages the persistent NSStatusItem in the macOS menu bar.
// Renders an SF Symbol icon as a template image (adapts to light/dark mode),
// builds the dropdown menu, and provides methods for other subsystems to
// update the displayed status (idle, recording, transcribing).

import AppKit
import SwiftUI

// MARK: - MenuBarStatus

/// The current operational state represented by the menu bar icon.
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

    /// The current operational status used for the menu bar icon.
    private(set) var status: MenuBarStatus = .idle

    /// External callback invoked when the user selects "Settings...".
    var onOpenSettings: (() -> Void)?

    /// External callback invoked when the user selects "History...".
    var onOpenHistory: (() -> Void)?

    /// External callback invoked when the user selects "Vocabulary...".
    var onOpenVocabulary: (() -> Void)?

    /// Weak reference to a DictationManager to read the transcription count.
    weak var dictationManager: DictationManager?

    // MARK: - Setup

    /// Converts DictationManager's state flags to a menu bar status.
    nonisolated static func statusFor(isDictating: Bool, isProcessing: Bool) -> MenuBarStatus {
        if isDictating { return .recording }
        if isProcessing { return .transcribing }
        return .idle
    }

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

    /// Updates the operational status displayed in the menu bar icon.
    func updateStatus(_ newStatus: MenuBarStatus) {
        status = newStatus

        if let button = statusItem?.button {
            button.image = statusBarImage(for: newStatus)
            button.image?.isTemplate = true
        }

        rebuildMenu()
    }

    // MARK: - Menu Construction

    /// Rebuilds the dropdown menu to reflect current state.
    func rebuildMenu() {
        let count = dictationManager?.transcriptionCount ?? 0
        let newMenu = buildMenu(transcriptionCount: count)
        self.menu = newMenu
        statusItem?.menu = newMenu
    }

    func buildMenu(transcriptionCount: Int) -> NSMenu {
        let newMenu = NSMenu()

        let titleItem = NSMenuItem(title: "Mumble", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        newMenu.addItem(titleItem)

        let subtitleItem = NSMenuItem(
            title: transcriptionCount == 1 ? "1 transcription" : "\(transcriptionCount) transcriptions",
            action: nil,
            keyEquivalent: ""
        )
        subtitleItem.isEnabled = false
        subtitleItem.indentationLevel = 1
        newMenu.addItem(subtitleItem)

        let historyItem = NSMenuItem(
            title: "History\u{2026}",
            action: #selector(openHistoryAction),
            keyEquivalent: ""
        )
        historyItem.target = self
        newMenu.addItem(historyItem)
        newMenu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings\u{2026}",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        newMenu.addItem(settingsItem)

        let vocabularyItem = NSMenuItem(
            title: "Vocabulary\u{2026}",
            action: #selector(openVocabularyAction),
            keyEquivalent: ""
        )
        vocabularyItem.target = self
        newMenu.addItem(vocabularyItem)

        let aboutItem = NSMenuItem(
            title: "About Mumble",
            action: #selector(openAboutAction),
            keyEquivalent: ""
        )
        aboutItem.target = self
        newMenu.addItem(aboutItem)

        newMenu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Mumble",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        quitItem.target = self
        newMenu.addItem(quitItem)

        return newMenu
    }

    // MARK: - Menu Actions

    @objc private func openSettingsAction() {
        onOpenSettings?()
    }

    @objc private func openHistoryAction() {
        onOpenHistory?()
    }

    @objc private func openVocabularyAction() {
        onOpenVocabulary?()
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
