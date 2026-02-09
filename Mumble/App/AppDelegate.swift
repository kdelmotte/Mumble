// AppDelegate.swift
// Mumble
//
// NSApplicationDelegate for Mumble. Responsible for:
// - Setting the activation policy to .accessory (no Dock icon)
// - Creating the MenuBarManager and wiring it to shared state
// - Launching the onboarding window on first run
// - Starting DictationManager after onboarding completes
// - Handling app lifecycle events (terminate, reopen)

import AppKit
import SwiftUI
import Combine

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    /// The shared application state. Both this delegate and the SwiftUI scenes
    /// reference the same `AppState.shared` singleton.
    private let appState = AppState.shared

    /// Handles the status bar item, its menu, and click actions.
    private var menuBarManager: MenuBarManager?

    /// Subscription bag for Combine pipelines.
    private var cancellables = Set<AnyCancellable>()

    /// Dedicated cancellable for the current DictationManager's transcription count.
    private var transcriptionCountCancellable: AnyCancellable?

    /// Reference to the onboarding window so we can bring it to front on
    /// reopen or close it when onboarding completes.
    private var onboardingWindow: NSWindow?

    /// Reference to the manually-managed Settings window (the SwiftUI Settings
    /// scene doesn't open reliably in .accessory mode).
    private var settingsWindow: NSWindow?

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {

        // 1. Decide activation policy up-front. During onboarding we use
        //    .regular so macOS treats our windows like a normal app (the TCC
        //    permission dialog won't cause them to vanish). Once onboarding
        //    completes we switch to .accessory (no Dock icon).
        if appState.hasCompletedOnboarding {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }

        // 2. Set up the menu bar status item.
        let menuBar = MenuBarManager()
        menuBar.dictationManager = appState.dictationManager
        menuBar.onOpenSettings = { [weak self] in
            self?.showSettingsWindow()
        }
        menuBar.setup()
        self.menuBarManager = menuBar
        appState.menuBarManager = menuBar

        // Keep menuBarManager.dictationManager in sync with appState
        // (it may be nil at launch and created lazily after onboarding).
        appState.$dictationManager
            .receive(on: RunLoop.main)
            .sink { [weak self] (manager: DictationManager?) in
                guard let self else { return }
                self.menuBarManager?.dictationManager = manager
                self.menuBarManager?.rebuildMenu()

                // Also subscribe to transcriptionCount changes on the new manager.
                self.subscribeToDictationCount(manager)
            }
            .store(in: &cancellables)

        // 3. Listen for notification-based window requests (from menu bar
        //    actions, keyboard shortcuts, etc.).
        subscribeToNotifications()

        // 4. Observe app activation so we can restore the onboarding window
        //    after system dialogs (TCC, Accessibility) steal focus.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        // 5. Decide initial flow.
        if appState.hasCompletedOnboarding {
            // Normal launch -- start dictation immediately.
            appState.configureDictationManager()
            STTLogger.shared.info("App launched -- onboarding already complete, dictation started")
        } else {
            // First launch -- show onboarding.
            showOnboardingWindow()
            STTLogger.shared.info("App launched -- showing onboarding")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.tearDownDictationManager()
        menuBarManager?.tearDown()
        STTLogger.shared.info("App will terminate -- cleanup complete")
    }

    /// Called when the user clicks the Dock icon (if visible) or re-launches
    /// the app while it is already running. We use this to surface the
    /// onboarding or settings window as appropriate.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            if !appState.hasCompletedOnboarding {
                showOnboardingWindow()
            } else {
                showSettingsWindow()
            }
        } else {
            bringWindowsToFront()
        }
        return false
    }

    // MARK: - Activation Recovery

    /// When the app regains focus (e.g. after the TCC dialog closes), make
    /// sure the onboarding window is visible and in front.
    @objc private func appDidBecomeActive(_ notification: Notification) {
        // Re-check permissions immediately when the user switches back from
        // System Settings, rather than waiting for the 2-second polling timer.
        appState.permissionManager.refreshPermissions()
        guard let window = onboardingWindow else { return }
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window Management

    /// Opens (or brings to front) the onboarding window.
    func showOnboardingWindow() {
        // If the window already exists, just bring it forward.
        if let existing = onboardingWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        appState.isOnboardingWindowOpen = true

        // Build the onboarding SwiftUI view hierarchy with all required
        // environment objects.
        let onboardingView = OnboardingContainerView(appState: appState)
            .environmentObject(appState)
            .environmentObject(appState.permissionManager)
            .environmentObject(appState.loginItemManager)
            .environmentObject(appState.audioRecorder)
            .environmentObject(appState.soundPlayer)

        let hostingController = NSHostingController(rootView: onboardingView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Welcome to Mumble"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 620))
        window.center()
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.onboardingWindow = window

        STTLogger.shared.debug("Onboarding window presented")
    }

    /// Opens (or brings to front) the Settings window. Managed manually via
    /// NSWindow + NSHostingController because the SwiftUI Settings scene
    /// doesn't open reliably in `.accessory` activation mode.
    func showSettingsWindow() {
        // If the window already exists, just bring it forward.
        if let existing = settingsWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsContainerView(appState: appState)
            .environmentObject(appState)
            .environmentObject(appState.permissionManager)
            .environmentObject(appState.loginItemManager)
            .environmentObject(appState.audioRecorder)
            .environmentObject(appState.soundPlayer)

        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "Mumble Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 640, height: 580))
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.makeKeyAndOrderFront(nil)

        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window

        STTLogger.shared.debug("Settings window presented")
    }

    /// Brings all visible windows to the front and activates the app.
    private func bringWindowsToFront() {
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.isVisible && window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: - Dictation Count Subscription

    /// Subscribes to a DictationManager's `$transcriptionCount` so the menu
    /// bar is rebuilt whenever a new transcription completes.
    private func subscribeToDictationCount(_ manager: DictationManager?) {
        transcriptionCountCancellable?.cancel()
        transcriptionCountCancellable = nil
        guard let manager else { return }
        transcriptionCountCancellable = manager.$transcriptionCount
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.menuBarManager?.rebuildMenu()
            }
    }

    // MARK: - Notification Subscriptions

    private func subscribeToNotifications() {
        NotificationCenter.default.publisher(for: .showSettings)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showSettingsWindow()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .showOnboarding)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showOnboardingWindow()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .onboardingDidComplete)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleOnboardingCompleted()
            }
            .store(in: &cancellables)
    }

    /// Invoked when onboarding finishes. Closes the onboarding window and
    /// ensures dictation monitoring begins.
    private func handleOnboardingCompleted() {
        let window = onboardingWindow
        onboardingWindow = nil          // clear first so windowWillClose guard skips
        window?.close()

        // Switch to accessory (no Dock icon) now that onboarding is done.
        NSApp.setActivationPolicy(.accessory)

        // AppState.completeOnboarding() is also called from the SwiftUI
        // OnboardingContainerView, but we call it here too to guarantee
        // the flag is set even if the notification arrives first.
        if !appState.hasCompletedOnboarding {
            appState.completeOnboarding()
        }

        // Ensure dictation is running (idempotent if already configured).
        appState.configureDictationManager()

        STTLogger.shared.info("Onboarding completed -- transitioned to menu bar mode")
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {

    /// When the user closes the onboarding window via the red close button
    /// before completing onboarding, we keep the app running in the menu bar.
    /// The user can re-trigger onboarding from the menu bar menu.
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        if window === onboardingWindow {
            appState.isOnboardingWindowOpen = false
            onboardingWindow = nil

            // Return to accessory mode (no Dock icon) if onboarding was dismissed.
            NSApp.setActivationPolicy(.accessory)

            STTLogger.shared.debug("Onboarding window closed by user")
        } else if window === settingsWindow {
            settingsWindow = nil
            STTLogger.shared.debug("Settings window closed by user")
        }
    }
}
