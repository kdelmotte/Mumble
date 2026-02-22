import XCTest
@testable import Mumble

final class VocabularyReplacerTests: XCTestCase {

    // MARK: - Basic Replacement

    func testBasicReplacement() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "I asked cloud about it")
        XCTAssertEqual(result, "I asked Claude about it")
    }

    // MARK: - Case Insensitive

    func testCaseInsensitive() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "Cloud is helpful")
        XCTAssertEqual(result, "Claude is helpful")
    }

    func testCaseInsensitive_allCaps() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "CLOUD is great")
        XCTAssertEqual(result, "Claude is great")
    }

    // MARK: - Word Boundaries

    func testWordBoundary_doesNotMatchPartialWord() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "iCloud is an Apple service")
        XCTAssertEqual(result, "iCloud is an Apple service")
    }

    func testWordBoundary_matchesAtStartOfString() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "cloud said hello")
        XCTAssertEqual(result, "Claude said hello")
    }

    func testWordBoundary_matchesAtEndOfString() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "I spoke to cloud")
        XCTAssertEqual(result, "I spoke to Claude")
    }

    // MARK: - Multi-Word Phrases

    func testMultiWordPhrase() {
        let entries = [VocabularyEntry(spoken: "whisper flow", corrected: "Wispr Flow")]
        let result = VocabularyReplacer.apply(entries, to: "I use whisper flow for dictation")
        XCTAssertEqual(result, "I use Wispr Flow for dictation")
    }

    // MARK: - Special Characters

    func testSpecialCharacters_dot() {
        let entries = [VocabularyEntry(spoken: "claude.md", corrected: "CLAUDE.md")]
        let result = VocabularyReplacer.apply(entries, to: "Check the claude.md file")
        XCTAssertEqual(result, "Check the CLAUDE.md file")
    }

    // MARK: - Multiple Entries

    func testMultipleEntries() {
        let entries = [
            VocabularyEntry(spoken: "cloud", corrected: "Claude"),
            VocabularyEntry(spoken: "whisper flow", corrected: "Wispr Flow"),
        ]
        let result = VocabularyReplacer.apply(entries, to: "I asked cloud about whisper flow")
        XCTAssertEqual(result, "I asked Claude about Wispr Flow")
    }

    // MARK: - Multiple Occurrences

    func testMultipleOccurrences() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = VocabularyReplacer.apply(entries, to: "cloud told me that cloud is helpful")
        XCTAssertEqual(result, "Claude told me that Claude is helpful")
    }

    // MARK: - Empty / Invalid Entries

    func testEmptyEntries_returnsOriginal() {
        let result = VocabularyReplacer.apply([], to: "Hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testInvalidEntries_skipped() {
        let entries = [
            VocabularyEntry(spoken: "", corrected: "Claude"),
            VocabularyEntry(spoken: "cloud", corrected: ""),
        ]
        let result = VocabularyReplacer.apply(entries, to: "I asked cloud")
        XCTAssertEqual(result, "I asked cloud")
    }

    // MARK: - Dictation Rule-Based Formatting

    func testRuleBasedFormatting_appliesToneAndVocabulary() {
        let entries = [VocabularyEntry(spoken: "cloud", corrected: "Claude")]
        let result = DictationManager.applyRuleBasedFormatting(
            "i asked cloud about it",
            tone: .casual,
            vocabularyEntries: entries
        )

        XCTAssertTrue(result.hasPrefix("I"), "Tone formatting should capitalize first word. Got: \(result)")
        XCTAssertTrue(result.contains("Claude"), "Vocabulary replacement should apply after tone formatting. Got: \(result)")
    }

    func testRuleBasedFormatting_emptyVocabulary_stillAppliesTone() {
        let result = DictationManager.applyRuleBasedFormatting(
            "hello there",
            tone: .professional,
            vocabularyEntries: []
        )

        XCTAssertEqual(result, "Hello there.", "Tone formatting should still run when vocabulary list is empty.")
    }
}
