import XCTest
@testable import Mumble

final class ToneTransformerTests: XCTestCase {

    private var transformer: ToneTransformer!

    override func setUp() {
        super.setUp()
        transformer = ToneTransformer()
    }

    override func tearDown() {
        transformer = nil
        super.tearDown()
    }

    // MARK: - Casual Tone

    func testCasualTone_unpunctuatedInput_capitalizesAndPunctuates() {
        let input = "hey are you free for lunch tomorrow let's do 12 if that works for you"
        let result = transformer.transform(input, tone: .casual)

        // Should capitalize the first letter of (at least) the first sentence.
        XCTAssertTrue(result.hasPrefix("Hey"), "Casual tone should capitalize the first word. Got: \(result)")

        // Should contain a question mark since the opening clause is a question.
        XCTAssertTrue(result.contains("?"), "Casual tone should insert a question mark for question-like clauses. Got: \(result)")

        // Should end with a period (last sentence is a statement).
        XCTAssertTrue(result.hasSuffix("."), "Casual tone should end with a period. Got: \(result)")
    }

    func testCasualTone_alreadyPunctuated_preservesStructure() {
        let input = "Hello there. How are you?"
        let result = transformer.transform(input, tone: .casual)

        // The text is already well-punctuated; casual tone should preserve its structure.
        XCTAssertTrue(result.contains("Hello"), "Casual tone should preserve capitalization. Got: \(result)")
        XCTAssertTrue(result.contains("."), "Casual tone should preserve existing periods. Got: \(result)")
        XCTAssertTrue(result.contains("?"), "Casual tone should preserve existing question marks. Got: \(result)")
    }

    // MARK: - Very Casual Tone

    func testVeryCasualTone_unpunctuatedInput_lowercasesAndAddsQuestionMark() {
        let input = "hey are you free for lunch tomorrow let's do 12 if that works for you"
        let result = transformer.transform(input, tone: .veryCasual)

        // Very casual should start with a lowercase letter.
        guard let firstChar = result.first else {
            XCTFail("Result should not be empty")
            return
        }
        XCTAssertTrue(firstChar.isLowercase, "Very casual tone should start lowercase. Got: \(result)")

        // Should still contain a question mark where a question is detected.
        XCTAssertTrue(result.contains("?"), "Very casual tone should still insert question marks. Got: \(result)")

        // Should NOT end with a period (very casual drops trailing period).
        XCTAssertFalse(result.hasSuffix("."), "Very casual tone should not end with a period. Got: \(result)")
    }

    func testVeryCasualTone_alreadyPunctuated_lowercasesStart() {
        let input = "Hello there. How are you?"
        let result = transformer.transform(input, tone: .veryCasual)

        // The first character should be lowercased in very casual mode.
        guard let firstChar = result.first else {
            XCTFail("Result should not be empty")
            return
        }
        XCTAssertTrue(firstChar.isLowercase, "Very casual tone should lowercase the first character. Got: \(result)")
    }

    // MARK: - Professional Tone

    func testProfessionalTone_expandsContractions() {
        let input = "I don't think we can't do this. She won't agree."
        let result = transformer.transform(input, tone: .professional)

        XCTAssertTrue(result.contains("do not"), "Professional tone should expand \"don't\" to \"do not\". Got: \(result)")
        XCTAssertTrue(result.contains("cannot"), "Professional tone should expand \"can't\" to \"cannot\". Got: \(result)")
        XCTAssertTrue(result.contains("will not"), "Professional tone should expand \"won't\" to \"will not\". Got: \(result)")
    }

    func testProfessionalTone_capitalizesAndPunctuates() {
        let input = "hello there how are you doing today"
        let result = transformer.transform(input, tone: .professional)

        XCTAssertTrue(result.hasPrefix("H"), "Professional tone should capitalize the first letter. Got: \(result)")
        XCTAssertTrue(result.hasSuffix(".") || result.hasSuffix("?") || result.hasSuffix("!"),
                       "Professional tone should end with punctuation. Got: \(result)")
    }

    func testProfessionalTone_alreadyPunctuated_preservesStructure() {
        let input = "Hello there. How are you?"
        let result = transformer.transform(input, tone: .professional)

        XCTAssertTrue(result.contains("Hello"), "Professional tone should preserve capitalization. Got: \(result)")
        XCTAssertTrue(result.contains("."), "Professional tone should preserve existing periods. Got: \(result)")
        XCTAssertTrue(result.contains("?"), "Professional tone should preserve existing question marks. Got: \(result)")
    }

    // MARK: - Empty and Minimal Input

    func testEmptyString_returnsEmpty() {
        let casualResult = transformer.transform("", tone: .casual)
        XCTAssertEqual(casualResult, "", "Empty input should return empty string for casual tone")

        let veryCasualResult = transformer.transform("", tone: .veryCasual)
        XCTAssertEqual(veryCasualResult, "", "Empty input should return empty string for very casual tone")
    }

    func testWhitespaceOnly_returnsEmpty() {
        let result = transformer.transform("   ", tone: .casual)
        XCTAssertEqual(result, "", "Whitespace-only input should return empty string")
    }

    func testSingleWord_casual_capitalizesAndPunctuates() {
        let result = transformer.transform("hello", tone: .casual)

        // Should capitalize the word.
        XCTAssertTrue(result.hasPrefix("Hello"), "Single word should be capitalized in casual tone. Got: \(result)")

        // Should end with punctuation.
        let lastChar = result.last
        XCTAssertNotNil(lastChar)
        XCTAssertTrue(lastChar == "." || lastChar == "!" || lastChar == "?",
                       "Single word in casual tone should end with punctuation. Got: \(result)")
    }

    func testSingleWord_veryCasual_lowercasesAndNoPeriod() {
        let result = transformer.transform("Hello", tone: .veryCasual)

        // Should lowercase the first character.
        guard let firstChar = result.first else {
            XCTFail("Result should not be empty")
            return
        }
        XCTAssertTrue(firstChar.isLowercase, "Single word should be lowercased in very casual tone. Got: \(result)")

        // Should not end with a period.
        XCTAssertFalse(result.hasSuffix("."), "Single word in very casual tone should not end with a period. Got: \(result)")
    }

    // MARK: - Contractions

    func testContractions_preservedInCasualTone() {
        let input = "don't let's won't"
        let result = transformer.transform(input, tone: .casual)

        XCTAssertTrue(result.contains("don't") || result.contains("Don't"),
                       "Contraction \"don't\" should be preserved. Got: \(result)")
        XCTAssertTrue(result.contains("let's") || result.contains("Let's"),
                       "Contraction \"let's\" should be preserved. Got: \(result)")
        XCTAssertTrue(result.contains("won't") || result.contains("Won't"),
                       "Contraction \"won't\" should be preserved. Got: \(result)")
    }

    func testContractions_preservedInVeryCasualTone() {
        let input = "don't let's won't"
        let result = transformer.transform(input, tone: .veryCasual)

        XCTAssertTrue(result.contains("don't"), "Contraction \"don't\" should be preserved in very casual. Got: \(result)")
        XCTAssertTrue(result.contains("let's"), "Contraction \"let's\" should be preserved in very casual. Got: \(result)")
        XCTAssertTrue(result.contains("won't"), "Contraction \"won't\" should be preserved in very casual. Got: \(result)")
    }

    // MARK: - Pronoun "I"

    func testPronounI_preservedInVeryCasualTone() {
        let input = "I think I'm going"
        let result = transformer.transform(input, tone: .veryCasual)

        // The pronoun "I" (and contractions starting with "I'") should remain uppercase
        // even in very casual mode, since lowercaseFirstUnlessProper checks for "I".
        XCTAssertTrue(result.contains("I"), "Pronoun \"I\" should remain uppercase in very casual tone. Got: \(result)")
    }

    func testPronounI_atStartOfSentence_preservedInVeryCasual() {
        // When "I" is the first word, it should stay uppercase due to the "I" check.
        let input = "I need to go"
        let result = transformer.transform(input, tone: .veryCasual)

        XCTAssertTrue(result.hasPrefix("I"), "Sentence starting with \"I\" should stay uppercase in very casual tone. Got: \(result)")
    }

    // MARK: - Multiple Sentences

    func testMultipleSentences_casual_allCapitalizedAndPunctuated() {
        let input = "Hello there. How are you? I am fine."
        let result = transformer.transform(input, tone: .casual)

        // All sentences should retain capitalization and punctuation.
        XCTAssertTrue(result.contains("Hello"), "First sentence should remain capitalized. Got: \(result)")
        XCTAssertTrue(result.contains("?"), "Question mark should be preserved. Got: \(result)")
        XCTAssertTrue(result.hasSuffix("."), "Last sentence should end with a period. Got: \(result)")
    }

    func testExclamationMark_preserved() {
        let input = "Wow that is great!"
        let casualResult = transformer.transform(input, tone: .casual)
        XCTAssertTrue(casualResult.contains("!"), "Exclamation mark should be preserved in casual tone. Got: \(casualResult)")

        let veryCasualResult = transformer.transform(input, tone: .veryCasual)
        XCTAssertTrue(veryCasualResult.contains("!"), "Exclamation mark should be preserved in very casual tone. Got: \(veryCasualResult)")
    }
}
