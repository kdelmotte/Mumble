import XCTest
@testable import Mumble

final class TranscriptionParserTests: XCTestCase {

    private let decoder = JSONDecoder()

    // MARK: - Valid JSON Parsing

    func testValidJSON_parsesCorrectly() throws {
        let json = #"{"text": "hello world"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TranscriptionResponse.self, from: data)
        XCTAssertEqual(response.text, "hello world")
    }

    func testValidJSON_withUnicode_parsesCorrectly() throws {
        let json = #"{"text": "caf\u00e9"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TranscriptionResponse.self, from: data)
        XCTAssertEqual(response.text, "caf\u{00e9}")
    }

    func testValidJSON_withEmptyText_parsesWithEmptyString() throws {
        let json = #"{"text": ""}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TranscriptionResponse.self, from: data)
        XCTAssertEqual(response.text, "")
    }

    func testValidJSON_withLongText_parsesCorrectly() throws {
        let longText = String(repeating: "word ", count: 1000).trimmingCharacters(in: .whitespaces)
        let json = "{\"text\": \"\(longText)\"}"
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TranscriptionResponse.self, from: data)
        XCTAssertEqual(response.text, longText)
    }

    func testValidJSON_withSpecialCharacters_parsesCorrectly() throws {
        let json = #"{"text": "hello \"world\" \n new line"}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let response = try decoder.decode(TranscriptionResponse.self, from: data)
        XCTAssertTrue(response.text.contains("hello"))
        XCTAssertTrue(response.text.contains("world"))
    }

    // MARK: - Invalid JSON Parsing

    func testMissingTextField_decodingFails() {
        let json = #"{}"#
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TranscriptionResponse.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError, "Error should be a DecodingError, got: \(error)")
        }
    }

    func testWrongFieldName_decodingFails() {
        let json = #"{"transcription": "hello world"}"#
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TranscriptionResponse.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError, "Error should be a DecodingError, got: \(error)")
        }
    }

    func testMalformedJSON_decodingFails() {
        let json = "this is not json"
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TranscriptionResponse.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError, "Error should be a DecodingError, got: \(error)")
        }
    }

    func testTextFieldAsNumber_decodingFails() {
        let json = #"{"text": 42}"#
        let data = json.data(using: .utf8)!

        XCTAssertThrowsError(try decoder.decode(TranscriptionResponse.self, from: data)) { error in
            XCTAssertTrue(error is DecodingError, "Error should be a DecodingError for type mismatch, got: \(error)")
        }
    }

    // MARK: - TranscriptionError Descriptions

    func testTranscriptionError_noAPIKey_hasDescription() {
        let error = TranscriptionError.noAPIKey
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "noAPIKey should have a non-empty description")
    }

    func testTranscriptionError_invalidAPIKey_hasDescription() {
        let error = TranscriptionError.invalidAPIKey
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "invalidAPIKey should have a non-empty description")
    }

    func testTranscriptionError_networkError_hasDescription() {
        let underlying = NSError(domain: NSURLErrorDomain, code: -1009, userInfo: [
            NSLocalizedDescriptionKey: "The Internet connection appears to be offline."
        ])
        let error = TranscriptionError.networkError(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "networkError should have a non-empty description")
    }

    func testTranscriptionError_rateLimited_withRetryAfter_hasDescription() {
        let error = TranscriptionError.rateLimited(retryAfter: 30)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "rateLimited with retryAfter should have a non-empty description")
        XCTAssertTrue(error.errorDescription!.contains("30"), "Description should mention the retry duration")
    }

    func testTranscriptionError_rateLimited_nilRetryAfter_hasDescription() {
        let error = TranscriptionError.rateLimited(retryAfter: nil)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "rateLimited without retryAfter should have a non-empty description")
    }

    func testTranscriptionError_serverError_hasDescription() {
        let error = TranscriptionError.serverError(statusCode: 500, message: "Internal Server Error")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "serverError should have a non-empty description")
        XCTAssertTrue(error.errorDescription!.contains("500"), "Description should include the status code")
    }

    func testTranscriptionError_invalidAudioData_hasDescription() {
        let error = TranscriptionError.invalidAudioData
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "invalidAudioData should have a non-empty description")
    }

    func testTranscriptionError_decodingError_hasDescription() {
        let underlying = NSError(domain: "TestDomain", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Unexpected format"
        ])
        let error = TranscriptionError.decodingError(underlying)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "decodingError should have a non-empty description")
    }

    func testTranscriptionError_timeout_hasDescription() {
        let error = TranscriptionError.timeout
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription!.isEmpty, "timeout should have a non-empty description")
    }
}
