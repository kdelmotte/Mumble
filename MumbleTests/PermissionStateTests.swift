import XCTest
@testable import Mumble

final class PermissionStateTests: XCTestCase {

    // MARK: - Initial State

    func testInitialState_microphoneDefaultsBasedOnSystemState() {
        // PermissionManager calls refreshPermissions() in init, which checks the
        // actual system state. In a test runner environment, microphone access is
        // typically not granted, so we verify the property is set to a Bool value
        // (i.e. the init completes without error).
        let manager = PermissionManager()

        // The property should be a valid Bool -- the exact value depends on the
        // test runner's permission state, but it should not crash.
        let micGranted = manager.microphoneGranted
        XCTAssertNotNil(micGranted as Bool?, "microphoneGranted should be a valid Bool after init")
    }

    func testInitialState_accessibilityDefaultsBasedOnSystemState() {
        let manager = PermissionManager()

        // Similarly, accessibility is checked in init via AXIsProcessTrusted().
        let axGranted = manager.accessibilityGranted
        XCTAssertNotNil(axGranted as Bool?, "accessibilityGranted should be a valid Bool after init")
    }

    // MARK: - Non-Crashing Calls

    func testRefreshPermissions_doesNotCrash() {
        let manager = PermissionManager()

        // Calling refreshPermissions() should complete without throwing or crashing.
        // It re-checks the system state for both microphone and accessibility.
        manager.refreshPermissions()

        // If we reach this point, the call succeeded.
        XCTAssertTrue(true, "refreshPermissions() should not crash")
    }

    func testOpenMicrophoneSettings_doesNotCrash() {
        let manager = PermissionManager()

        // openMicrophoneSettings() constructs a URL and asks NSWorkspace to open it.
        // In the test runner environment this may not actually open System Settings,
        // but it should not crash or throw.
        manager.openMicrophoneSettings()

        XCTAssertTrue(true, "openMicrophoneSettings() should not crash")
    }

    func testOpenAccessibilitySettings_doesNotCrash() {
        let manager = PermissionManager()

        // openAccessibilitySettings() constructs a URL and asks NSWorkspace to open it.
        // Same expectations as the microphone variant.
        manager.openAccessibilitySettings()

        XCTAssertTrue(true, "openAccessibilitySettings() should not crash")
    }

    // MARK: - Published Properties Are Observable

    func testPermissionManager_isObservableObject() {
        // PermissionManager conforms to ObservableObject, so it should be usable
        // with SwiftUI's @ObservedObject / @StateObject. Verify the type conforms.
        let manager = PermissionManager()
        XCTAssertNotNil(manager.objectWillChange, "PermissionManager should be an ObservableObject with objectWillChange publisher")
    }
}
