import XCTest
@testable import Mumble

final class ToneMappingConfigTests: XCTestCase {

    // MARK: - AppGroup.group(for:) Mapping

    func testMessagesBundle_mapsToPersonal() {
        XCTAssertEqual(AppGroup.group(for: "com.apple.MobileSMS"), .personal)
    }

    func testDiscordBundle_mapsToPersonal() {
        XCTAssertEqual(AppGroup.group(for: "com.hnc.Discord"), .personal)
    }

    func testMailBundle_mapsToWork() {
        XCTAssertEqual(AppGroup.group(for: "com.apple.mail"), .work)
    }

    func testSlackBundle_mapsToWork() {
        XCTAssertEqual(AppGroup.group(for: "com.tinyspeck.slackmacgap"), .work)
    }

    func testSafariBundle_mapsToWork() {
        XCTAssertEqual(AppGroup.group(for: "com.apple.Safari"), .work)
    }

    func testChromeBundle_mapsToWork() {
        XCTAssertEqual(AppGroup.group(for: "com.google.Chrome"), .work)
    }

    func testArcBundle_mapsToWork() {
        XCTAssertEqual(AppGroup.group(for: "company.thebrowser.Browser"), .work)
    }

    func testEdgeBundle_mapsToWork() {
        XCTAssertEqual(AppGroup.group(for: "com.microsoft.edgemac"), .work)
    }

    func testUnknownBundle_mapsToOther() {
        XCTAssertEqual(AppGroup.group(for: "com.example.unknown"), .other)
    }

    // MARK: - Default Config Values

    func testDefaultConfig_personalIsVeryCasual() {
        let config = ToneMappingConfig.default
        XCTAssertEqual(config.personal, .veryCasual)
    }

    func testDefaultConfig_workIsCasual() {
        let config = ToneMappingConfig.default
        XCTAssertEqual(config.work, .casual)
    }

    func testDefaultConfig_otherIsCasual() {
        let config = ToneMappingConfig.default
        XCTAssertEqual(config.other, .casual)
    }

    // MARK: - tone(for:)

    func testToneForGroup_returnsCorrectProfile() {
        let config = ToneMappingConfig(personal: .professional, work: .veryCasual, other: .casual)
        XCTAssertEqual(config.tone(for: .personal), .professional)
        XCTAssertEqual(config.tone(for: .work), .veryCasual)
        XCTAssertEqual(config.tone(for: .other), .casual)
    }

    // MARK: - setTone(_:for:)

    func testSetTone_updatesPersonal() {
        var config = ToneMappingConfig.default
        config.setTone(.professional, for: .personal)
        XCTAssertEqual(config.personal, .professional)
    }

    func testSetTone_updatesWork() {
        var config = ToneMappingConfig.default
        config.setTone(.veryCasual, for: .work)
        XCTAssertEqual(config.work, .veryCasual)
    }

    func testSetTone_updatesOther() {
        var config = ToneMappingConfig.default
        config.setTone(.professional, for: .other)
        XCTAssertEqual(config.other, .professional)
    }

    // MARK: - Equatable

    func testEquatable_identicalConfigsAreEqual() {
        let a = ToneMappingConfig.default
        let b = ToneMappingConfig.default
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentConfigsAreNotEqual() {
        let a = ToneMappingConfig.default
        let b = ToneMappingConfig(personal: .professional, work: .casual, other: .casual)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let original = ToneMappingConfig(personal: .professional, work: .veryCasual, other: .casual)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ToneMappingConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - AppGroup Display Properties

    func testAppGroup_allCases() {
        XCTAssertEqual(AppGroup.allCases.count, 3)
        XCTAssertTrue(AppGroup.allCases.contains(.personal))
        XCTAssertTrue(AppGroup.allCases.contains(.work))
        XCTAssertTrue(AppGroup.allCases.contains(.other))
    }

    func testAppGroup_displayNames() {
        XCTAssertEqual(AppGroup.personal.displayName, "Personal")
        XCTAssertEqual(AppGroup.work.displayName, "Work")
        XCTAssertEqual(AppGroup.other.displayName, "Other")
    }

    func testAppGroup_otherHasEmptyBundleIDs() {
        XCTAssertTrue(AppGroup.other.bundleIDs.isEmpty)
    }
}
