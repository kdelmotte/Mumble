import XCTest
@testable import Mumble

final class VocabularyConfigTests: XCTestCase {

    // MARK: - VocabularyEntry.isValid

    func testIsValid_bothFieldsFilled_returnsTrue() {
        let entry = VocabularyEntry(spoken: "cloud", corrected: "Claude")
        XCTAssertTrue(entry.isValid)
    }

    func testIsValid_emptySpoken_returnsFalse() {
        let entry = VocabularyEntry(spoken: "", corrected: "Claude")
        XCTAssertFalse(entry.isValid)
    }

    func testIsValid_emptyCorrected_returnsFalse() {
        let entry = VocabularyEntry(spoken: "cloud", corrected: "")
        XCTAssertFalse(entry.isValid)
    }

    func testIsValid_bothEmpty_returnsFalse() {
        let entry = VocabularyEntry(spoken: "", corrected: "")
        XCTAssertFalse(entry.isValid)
    }

    func testIsValid_whitespaceOnlySpoken_returnsFalse() {
        let entry = VocabularyEntry(spoken: "   ", corrected: "Claude")
        XCTAssertFalse(entry.isValid)
    }

    func testIsValid_whitespaceOnlyCorrected_returnsFalse() {
        let entry = VocabularyEntry(spoken: "cloud", corrected: "  \t ")
        XCTAssertFalse(entry.isValid)
    }

    // MARK: - VocabularyConfig.validEntries

    func testValidEntries_filtersOutInvalid() {
        let config = VocabularyConfig(entries: [
            VocabularyEntry(spoken: "cloud", corrected: "Claude"),
            VocabularyEntry(spoken: "", corrected: "Wispr"),
            VocabularyEntry(spoken: "whisper flow", corrected: "Wispr Flow"),
        ])
        XCTAssertEqual(config.validEntries.count, 2)
        XCTAssertEqual(config.validEntries[0].spoken, "cloud")
        XCTAssertEqual(config.validEntries[1].spoken, "whisper flow")
    }

    func testValidEntries_emptyConfig() {
        let config = VocabularyConfig.default
        XCTAssertTrue(config.validEntries.isEmpty)
    }

    // MARK: - llmPromptSection

    func testLLMPromptSection_withValidEntries_containsPairs() {
        let config = VocabularyConfig(entries: [
            VocabularyEntry(spoken: "cloud", corrected: "Claude"),
        ])
        let section = config.llmPromptSection
        XCTAssertNotNil(section)
        XCTAssertTrue(section!.contains("\"cloud\" → \"Claude\""))
        XCTAssertTrue(section!.contains("Custom vocabulary"))
    }

    func testLLMPromptSection_noValidEntries_returnsNil() {
        let config = VocabularyConfig(entries: [
            VocabularyEntry(spoken: "", corrected: ""),
        ])
        XCTAssertNil(config.llmPromptSection)
    }

    func testLLMPromptSection_emptyEntries_returnsNil() {
        let config = VocabularyConfig.default
        XCTAssertNil(config.llmPromptSection)
    }

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        let original = VocabularyConfig(entries: [
            VocabularyEntry(spoken: "cloud", corrected: "Claude"),
            VocabularyEntry(spoken: "whisper flow", corrected: "Wispr Flow"),
        ])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(VocabularyConfig.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    // MARK: - Equatable

    func testEquatable_identicalConfigsAreEqual() {
        let id = UUID()
        let a = VocabularyConfig(entries: [VocabularyEntry(id: id, spoken: "cloud", corrected: "Claude")])
        let b = VocabularyConfig(entries: [VocabularyEntry(id: id, spoken: "cloud", corrected: "Claude")])
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentConfigsAreNotEqual() {
        let a = VocabularyConfig(entries: [VocabularyEntry(spoken: "cloud", corrected: "Claude")])
        let b = VocabularyConfig(entries: [VocabularyEntry(spoken: "cloud", corrected: "Klaud")])
        XCTAssertNotEqual(a, b)
    }
}
