import XCTest
@testable import Mumble

final class LLMFormattingServiceTests: XCTestCase {

    private var service: LLMFormattingService!

    override func setUp() {
        super.setUp()
        service = LLMFormattingService.shared
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Request Body Building

    func testBuildRequestBody_isValidJSON() throws {
        let data = try service.buildRequestBody(transcript: "hello world", systemPrompt: "Format this")
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(json, "Request body should be valid JSON")
    }

    func testBuildRequestBody_containsModel() throws {
        let data = try service.buildRequestBody(transcript: "hello", systemPrompt: "Format")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "llama-3.3-70b-versatile")
    }

    func testBuildRequestBody_containsTemperature() throws {
        let data = try service.buildRequestBody(transcript: "hello", systemPrompt: "Format")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["temperature"] as? Double, 0.1)
    }

    func testBuildRequestBody_containsMaxTokens() throws {
        let data = try service.buildRequestBody(transcript: "hello", systemPrompt: "Format")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["max_tokens"] as? Int, 1024)
    }

    func testBuildRequestBody_containsSystemPrompt() throws {
        let prompt = "You are a formatting assistant."
        let data = try service.buildRequestBody(transcript: "hello", systemPrompt: prompt)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])

        let systemMessage = messages.first { ($0["role"] as? String) == "system" }
        XCTAssertNotNil(systemMessage, "Should contain a system message")
        XCTAssertEqual(systemMessage?["content"] as? String, prompt)
    }

    func testBuildRequestBody_containsTranscript() throws {
        let transcript = "some test transcript"
        let data = try service.buildRequestBody(transcript: transcript, systemPrompt: "Format")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])

        let userMessage = messages.first { ($0["role"] as? String) == "user" }
        XCTAssertNotNil(userMessage, "Should contain a user message")
        let content = try XCTUnwrap(userMessage?["content"] as? String)
        XCTAssertTrue(content.contains("###TRANSCRIPT_START###"), "User message should contain start marker")
        XCTAssertTrue(content.contains(transcript), "User message should contain the transcript")
        XCTAssertTrue(content.contains("###TRANSCRIPT_END###"), "User message should contain end marker")
    }

    // MARK: - Output Validation

    func testValidateOutput_similarLength_doesNotThrow() {
        // 5 words in, ~5 words out — well within 3x
        XCTAssertNoThrow(try service.validateOutput("Hello there my good friend", originalTranscript: "hello there my good friend"))
    }

    func testValidateOutput_exactly3x_doesNotThrow() {
        // 2 input words, 6 output words (exactly 3x) — boundary, should pass
        let input = "hello world"
        let output = "Hello there, wonderful world, how exciting"
        XCTAssertNoThrow(try service.validateOutput(output, originalTranscript: input))
    }

    func testValidateOutput_over3x_throwsEmptyResponse() {
        // 2 input words, 7+ output words (over 3x) — should be rejected
        let input = "hello world"
        let output = "I'd be happy to help you format that text properly today"
        XCTAssertThrowsError(try service.validateOutput(output, originalTranscript: input)) { error in
            XCTAssertTrue(error is LLMFormattingError, "Should throw LLMFormattingError, got: \(error)")
        }
    }

    func testValidateOutput_emptyInput_singleWordOutput_doesNotThrow() {
        // Empty input → inputWords = max(0, 1) = 1, so up to 3 output words is fine
        XCTAssertNoThrow(try service.validateOutput("Hello", originalTranscript: ""))
    }

    // MARK: - Response Parsing

    func testParseResponse_200_validJSON_returnsContent() throws {
        let json = #"{"choices":[{"message":{"content":"Formatted text"}}]}"#
        let data = Data(json.utf8)
        let result = try service.parseResponse(data: data, statusCode: 200, originalTranscript: "some text")
        XCTAssertEqual(result, "Formatted text")
    }

    func testParseResponse_200_emptyContent_throwsEmptyResponse() {
        let json = #"{"choices":[{"message":{"content":""}}]}"#
        let data = Data(json.utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 200, originalTranscript: "some text")) { error in
            guard case LLMFormattingError.emptyResponse = error else {
                XCTFail("Expected emptyResponse, got: \(error)")
                return
            }
        }
    }

    func testParseResponse_200_whitespaceOnly_throwsEmptyResponse() {
        let json = #"{"choices":[{"message":{"content":"   \n  "}}]}"#
        let data = Data(json.utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 200, originalTranscript: "some text")) { error in
            guard case LLMFormattingError.emptyResponse = error else {
                XCTFail("Expected emptyResponse, got: \(error)")
                return
            }
        }
    }

    func testParseResponse_200_invalidJSON_throwsDecodingError() {
        let data = Data("not json".utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 200, originalTranscript: "text")) { error in
            guard case LLMFormattingError.decodingError = error else {
                XCTFail("Expected decodingError, got: \(error)")
                return
            }
        }
    }

    func testParseResponse_401_throwsInvalidResponse() {
        let json = #"{"error":{"message":"Invalid API key"}}"#
        let data = Data(json.utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 401, originalTranscript: "text")) { error in
            guard case LLMFormattingError.invalidResponse(let statusCode, _) = error else {
                XCTFail("Expected invalidResponse, got: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 401)
        }
    }

    func testParseResponse_500_throwsInvalidResponse() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 500, originalTranscript: "text")) { error in
            guard case LLMFormattingError.invalidResponse(let statusCode, _) = error else {
                XCTFail("Expected invalidResponse, got: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 500)
        }
    }

    // MARK: - Error Descriptions

    func testLLMFormattingError_allCases_haveDescriptions() {
        let cases: [LLMFormattingError] = [
            .noAPIKey,
            .invalidResponse(statusCode: 401, message: "Unauthorized"),
            .invalidResponse(statusCode: 500, message: nil),
            .emptyResponse,
            .networkError(NSError(domain: "test", code: 1)),
            .timeout,
            .decodingError(NSError(domain: "test", code: 2))
        ]

        for error in cases {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error \(error) should have a description")
            XCTAssertFalse(description!.isEmpty, "Error \(error) should have a non-empty description")
        }
    }
}
