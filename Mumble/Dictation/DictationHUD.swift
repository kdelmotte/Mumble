// DictationHUD.swift
// Mumble
//
// Floating HUD window that appears at the bottom center of the active screen
// while dictation is in progress. Uses an NSPanel to remain non-activating and
// always on top, embedding SwiftUI content via NSHostingView.

import AppKit
import SwiftUI

// MARK: - HUDState

/// Observable state object shared between the DictationHUD controller and the
/// SwiftUI content view. Using an ObservableObject lets SwiftUI efficiently
/// re-render only the parts that changed, preserving @State (e.g. the
/// animation timer in AudioWaveView) across updates.
@MainActor
final class HUDState: ObservableObject {
    @Published var audioLevel: Float = 0.0
    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false
}

// MARK: - HUDContentView

/// The SwiftUI content displayed inside the floating HUD panel.
private struct HUDContentView: View {

    @ObservedObject var state: HUDState

    var body: some View {
        AudioWaveView(
            audioLevel: $state.audioLevel,
            isRecording: state.isRecording,
            isProcessing: state.isProcessing
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial.opacity(0.9))
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.6))
                )
        )
        .clipShape(Capsule())
    }
}

// MARK: - DictationHUD

@MainActor
final class DictationHUD {

    // MARK: - State

    private var panel: NSPanel?
    private let state = HUDState()

    /// Hosting view that bridges SwiftUI into the NSPanel.
    private var hostingView: NSHostingView<AnyView>?

    /// Timer used to auto-hide after an error is shown.
    private var errorDismissTimer: Timer?

    // MARK: - Public API

    /// Creates the panel and shows it at the bottom center of the screen
    /// containing the current mouse cursor position.
    func show() {
        // If a panel already exists, just bring it to front.
        if let panel {
            panel.orderFrontRegardless()
            return
        }

        // Reset state for a fresh dictation session.
        state.audioLevel = 0.0
        state.isRecording = true
        state.isProcessing = false

        let contentView = makeHostingView()
        self.hostingView = contentView

        let panelSize = NSSize(width: 120, height: 52)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow

        panel.contentView = contentView

        positionPanel(panel, size: panelSize)

        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Hides the panel and releases all resources.
    func hide() {
        errorDismissTimer?.invalidate()
        errorDismissTimer = nil

        panel?.orderOut(nil)
        panel?.contentView = nil
        hostingView = nil
        panel = nil

        state.isRecording = false
        state.isProcessing = false
    }

    /// Updates the displayed audio level. Call this on each audio-level tick
    /// from the recorder.
    func updateAudioLevel(_ level: Float) {
        state.audioLevel = level
    }

    /// Transitions the HUD into "processing" state: freezes the waveform bars
    /// and greys them out with a spinner.
    func showProcessing() {
        state.isRecording = false
        state.isProcessing = true
    }

    /// Briefly shows an error state on the HUD, then hides automatically
    /// after a short delay.
    func showError(_ message: String) {
        state.isRecording = false
        state.isProcessing = false

        errorDismissTimer?.invalidate()
        errorDismissTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.hide()
            }
        }
    }

    // MARK: - Private Helpers

    /// Creates an NSHostingView wrapping the HUD SwiftUI content.
    private func makeHostingView() -> NSHostingView<AnyView> {
        let view = NSHostingView(rootView: AnyView(HUDContentView(state: state)))
        return view
    }

    /// Positions the panel at the bottom center of the screen that currently
    /// contains the mouse cursor.
    private func positionPanel(_ panel: NSPanel, size: NSSize) {
        let mouseLocation = NSEvent.mouseLocation
        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let visibleFrame = screen.visibleFrame
        let bottomMargin: CGFloat = 80

        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.minY + bottomMargin

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
