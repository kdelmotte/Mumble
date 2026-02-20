// MumbleApp.swift
// Mumble
//
// The @main entry point for Mumble. Configures the app as a menu bar
// accessory (no Dock icon), creates shared manager instances, and
// coordinates between the AppDelegate and SwiftUI scenes.

import SwiftUI

// MARK: - AppState

/// Shared observable state that bridges the AppDelegate world and the
/// SwiftUI scene world. Both sides reference the same singleton instance
/// obtained via `AppState.shared`.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    /// Process-wide shared instance. Created once on first access.
    static let shared = AppState()

    // MARK: - Onboarding

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: AppState.onboardingKey) }
    }

    @Published var isOnboardingWindowOpen: Bool = false

    static let onboardingKey = "hasCompletedOnboarding"

    // MARK: - Managers

    /// Shared instances owned by the app and injected into both AppDelegate and views.
    let permissionManager: PermissionManager
    let loginItemManager: LoginItemManager
    let audioRecorder: AudioRecorder
    let soundPlayer: SoundPlayer

    /// DictationManager is created lazily after onboarding completes (it
    /// requires the API key to be present). Set via `configureDictationManager()`.
    @Published var dictationManager: DictationManager?

    /// MenuBarManager is created by the AppDelegate once the status item is ready.
    @Published var menuBarManager: MenuBarManager?

    // MARK: - Init

    private init() {
        let completed = UserDefaults.standard.bool(forKey: AppState.onboardingKey)
        self.hasCompletedOnboarding = completed

        self.permissionManager = PermissionManager()
        self.loginItemManager = LoginItemManager()
        self.audioRecorder = AudioRecorder()
        self.soundPlayer = SoundPlayer()
    }

    // MARK: - Dictation Lifecycle

    /// Creates and starts the DictationManager. Safe to call multiple times --
    /// subsequent calls are no-ops if the manager already exists.
    func configureDictationManager() {
        guard dictationManager == nil else { return }

        let manager = DictationManager(
            audioRecorder: audioRecorder,
            soundPlayer: soundPlayer,
            permissionManager: permissionManager
        )
        self.dictationManager = manager
        manager.start()
        STTLogger.shared.info("DictationManager configured and monitoring started")
    }

    /// Tears down the DictationManager (e.g. on app termination).
    func tearDownDictationManager() {
        dictationManager?.stop()
        dictationManager = nil
        STTLogger.shared.info("DictationManager torn down")
    }

    /// Called when the user finishes onboarding. Updates the persisted flag,
    /// closes the onboarding window, and spins up dictation.
    func completeOnboarding() {
        hasCompletedOnboarding = true
        isOnboardingWindowOpen = false
        configureDictationManager()
    }
}

// MARK: - MumbleApp

@main
struct MumbleApp: App {

    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Shared State

    /// Both MumbleApp and AppDelegate share the same AppState singleton.
    /// Using @ObservedObject here because AppState.shared is not created by
    /// this view -- it is a pre-existing singleton.
    @ObservedObject private var appState = AppState.shared

    // MARK: - Body

    var body: some Scene {

        // Both the onboarding window and the settings window are managed
        // by the AppDelegate via NSWindow/NSHostingController. This avoids
        // issues with the SwiftUI Settings scene not opening reliably in
        // .accessory activation mode. A minimal Settings scene is kept here
        // because SwiftUI requires at least one scene in the body.
        Settings {
            EmptyView()
        }
    }
}

// MARK: - OnboardingContainerView

/// Wraps `OnboardingView` so it can receive the shared managers from AppState
/// and call `appState.completeOnboarding()` when the user finishes.
struct OnboardingContainerView: View {

    @ObservedObject var appState: AppState
    @StateObject private var viewModel: OnboardingViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(
            permissionManager: appState.permissionManager,
            keychainManager: .shared,
            loginItemManager: appState.loginItemManager
        ))
    }

    var body: some View {
        OnboardingView(viewModel: viewModel)
            .onReceive(
                NotificationCenter.default.publisher(for: .onboardingDidComplete)
            ) { _ in
                // The AppDelegate listens for this same notification and
                // closes its NSWindow in handleOnboardingCompleted().
                appState.completeOnboarding()
            }
            .onAppear {
                // Ensure the app is visible when the onboarding window shows.
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

// MARK: - SettingsContainerView

/// Wraps the settings content with proper dependency injection from AppState.
struct SettingsContainerView: View {

    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if let dictationManager = appState.dictationManager {
                SettingsHostView(
                    appState: appState,
                    dictationManager: dictationManager
                )
            } else {
                // Edge case: settings opened before onboarding completes.
                VStack(spacing: 16) {
                    Image(systemName: "gear.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)

                    Text("Complete onboarding to access settings.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 640, height: 300)
            }
        }
    }
}

/// The actual settings content, shown only when DictationManager is available.
struct SettingsHostView: View {

    @ObservedObject var appState: AppState
    let dictationManager: DictationManager

    @StateObject private var viewModel: SettingsViewModel

    init(appState: AppState, dictationManager: DictationManager) {
        self.appState = appState
        self.dictationManager = dictationManager
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            loginItemManager: appState.loginItemManager,
            audioRecorder: appState.audioRecorder,
            soundPlayer: appState.soundPlayer,
            dictationManager: dictationManager
        ))
    }

    var body: some View {
        SettingsView(viewModel: viewModel)
            .environmentObject(appState.permissionManager)
            .environmentObject(appState.loginItemManager)
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted by the final onboarding step when the user taps "Get Started".
    static let onboardingDidComplete = Notification.Name("Mumble.onboardingDidComplete")

    /// Posted when the app should open the Settings window.
    static let showSettings = Notification.Name("Mumble.showSettings")

    /// Posted when the app should open the onboarding window.
    static let showOnboarding = Notification.Name("Mumble.showOnboarding")

    /// Posted when the app should open Settings directly to the Vocabulary tab.
    static let showVocabulary = Notification.Name("Mumble.showVocabulary")
}
