import XCTest
@testable import Mumble

final class KeychainManagerTests: XCTestCase {

    private var manager: KeychainManager!

    override func setUp() {
        super.setUp()
        manager = KeychainManager(service: "com.mumble.test", account: "test-api-key")
    }

    override func tearDown() {
        // Clean up any test keychain entries
        try? manager.deleteAPIKey()
        manager = nil
        super.tearDown()
    }

    // MARK: - Save and Retrieve

    func testGetAPIKey_noKey_returnsNil() {
        XCTAssertNil(manager.getAPIKey(), "Should return nil when no key is stored")
    }

    func testSaveAndGet_roundTrip_returnsKey() throws {
        try manager.saveAPIKey("gsk_test123")
        XCTAssertEqual(manager.getAPIKey(), "gsk_test123")
    }

    func testSaveAPIKey_update_replacesExistingKey() throws {
        try manager.saveAPIKey("original-key")
        try manager.saveAPIKey("updated-key")
        XCTAssertEqual(manager.getAPIKey(), "updated-key")
    }

    func testSaveAPIKey_emptyString_savesAndReturns() throws {
        try manager.saveAPIKey("")
        XCTAssertEqual(manager.getAPIKey(), "")
    }

    func testSaveAPIKey_specialCharacters_roundTrips() throws {
        let specialKey = "gsk_test!@#$%^&*()_+🔑émoji"
        try manager.saveAPIKey(specialKey)
        XCTAssertEqual(manager.getAPIKey(), specialKey)
    }

    // MARK: - Delete

    func testDeleteAPIKey_existingKey_getReturnsNil() throws {
        try manager.saveAPIKey("key-to-delete")
        XCTAssertNotNil(manager.getAPIKey(), "Key should exist before deletion")

        try manager.deleteAPIKey()
        XCTAssertNil(manager.getAPIKey(), "Key should be nil after deletion")
    }

    func testDeleteAPIKey_noExistingKey_doesNotThrow() {
        XCTAssertNoThrow(try manager.deleteAPIKey(), "Deleting a non-existent key should not throw")
    }

    // MARK: - Error Descriptions

    func testKeychainError_allCases_haveDescriptions() {
        let cases: [KeychainError] = [
            .saveFailed(errSecDuplicateItem),
            .deleteFailed(errSecItemNotFound),
            .updateFailed(errSecAuthFailed),
            .unexpectedData,
            .encodingFailed
        ]

        for error in cases {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error \(error) should have a description")
            XCTAssertFalse(description!.isEmpty, "Error \(error) should have a non-empty description")
        }
    }
}
