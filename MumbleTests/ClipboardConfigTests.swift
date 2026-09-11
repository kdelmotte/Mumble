import XCTest
@testable import Mumble

final class ClipboardConfigTests: XCTestCase {

    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ClipboardConfigTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testAutomaticCopy_defaultsToDisabled() {
        XCTAssertFalse(ClipboardConfig.isAutomaticCopyEnabled(in: userDefaults))
    }

    func testAutomaticCopy_persistsEnabledValue() {
        ClipboardConfig.setAutomaticCopyEnabled(true, in: userDefaults)

        XCTAssertTrue(ClipboardConfig.isAutomaticCopyEnabled(in: userDefaults))
    }

    func testAutomaticCopy_persistsDisabledValue() {
        ClipboardConfig.setAutomaticCopyEnabled(true, in: userDefaults)
        ClipboardConfig.setAutomaticCopyEnabled(false, in: userDefaults)

        XCTAssertFalse(ClipboardConfig.isAutomaticCopyEnabled(in: userDefaults))
    }
}
