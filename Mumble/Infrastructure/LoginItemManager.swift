import Foundation
import ServiceManagement

// MARK: - LoginItemManager

final class LoginItemManager: ObservableObject {

    @Published private(set) var isEnabled: Bool = false

    private let appService = SMAppService.mainApp

    init() {
        refreshState()
    }

    // MARK: - Public API

    /// Enables the app as a login item so it launches at system startup.
    func enable() {
        do {
            try appService.register()
            refreshState()
        } catch {
            STTLogger.shared.error("Failed to enable login item: \(error.localizedDescription)")
            refreshState()
        }
    }

    /// Disables the app as a login item.
    func disable() {
        do {
            try appService.unregister()
            refreshState()
        } catch {
            STTLogger.shared.error("Failed to disable login item: \(error.localizedDescription)")
            refreshState()
        }
    }

    /// Toggles the login item state.
    func toggle() {
        if isEnabled {
            disable()
        } else {
            enable()
        }
    }

    // MARK: - Private Helpers

    private func refreshState() {
        let status = appService.status
        DispatchQueue.main.async {
            self.isEnabled = (status == .enabled)
        }
    }
}
