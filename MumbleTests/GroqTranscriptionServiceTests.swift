import XCTest
@testable import Mumble

final class GroqTranscriptionServiceTests: XCTestCase {

    private var service: GroqTranscriptionService!
    private let boundary = "TestBoundary-12345"
    private let sampleAudio = Data([0x52, 0x49, 0x46, 0x46]) // "RIFF" header bytes

    override func setUp() {
        super.setUp()
        service = GroqTranscriptionService.shared
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Multipart Body Building

    func testBuildMultipartBody_containsBoundaryMarkers() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json"
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertTrue(bodyString.contains("--\(boundary)"), "Body should contain boundary markers")
        XCTAssertTrue(bodyString.contains("--\(boundary)--"), "Body should end with closing boundary")
    }

    func testBuildMultipartBody_containsAudioData() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json"
        )

        // The raw audio bytes should appear somewhere in the body
        let range = body.range(of: sampleAudio)
        XCTAssertNotNil(range, "Body should contain the raw audio data")
    }

    func testBuildMultipartBody_containsModelField() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json"
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertTrue(bodyString.contains("name=\"model\""), "Body should contain model field")
        XCTAssertTrue(bodyString.contains("whisper-large-v3"), "Body should contain model value")
    }

    func testBuildMultipartBody_containsResponseFormatField() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json"
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertTrue(bodyString.contains("name=\"response_format\""), "Body should contain response_format field")
        XCTAssertTrue(bodyString.contains("json"), "Body should contain response format value")
    }

    func testBuildMultipartBody_includesPrompt_whenProvided() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json",
            prompt: "technical vocabulary"
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertTrue(bodyString.contains("name=\"prompt\""), "Body should contain prompt field when provided")
        XCTAssertTrue(bodyString.contains("technical vocabulary"), "Body should contain prompt value")
    }

    func testBuildMultipartBody_omitsPrompt_whenNil() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json",
            prompt: nil
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertFalse(bodyString.contains("name=\"prompt\""), "Body should not contain prompt field when nil")
    }

    func testBuildMultipartBody_includesLanguage_whenProvided() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json",
            language: "en"
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertTrue(bodyString.contains("name=\"language\""), "Body should contain language field when provided")
        XCTAssertTrue(bodyString.contains("en"), "Body should contain language value")
    }

    func testBuildMultipartBody_omitsLanguage_whenNil() {
        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-large-v3",
            responseFormat: "json",
            language: nil
        )
        let bodyString = String(data: body, encoding: .utf8)!

        XCTAssertFalse(bodyString.contains("name=\"language\""), "Body should not contain language field when nil")
    }

    // MARK: - Response Parsing

    func testParseResponse_200_validJSON_returnsText() throws {
        let json = #"{"text":"Hello world"}"#
        let data = Data(json.utf8)
        let result = try service.parseResponse(data: data, statusCode: 200)
        XCTAssertEqual(result, "Hello world")
    }

    func testParseResponse_200_invalidJSON_throwsDecodingError() {
        let data = Data("not json at all".utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 200)) { error in
            guard case TranscriptionError.decodingError = error else {
                XCTFail("Expected decodingError, got: \(error)")
                return
            }
        }
    }

    func testParseResponse_401_throwsInvalidAPIKey() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 401)) { error in
            guard case TranscriptionError.invalidAPIKey = error else {
                XCTFail("Expected invalidAPIKey, got: \(error)")
                return
            }
        }
    }

    func testParseResponse_429_throwsRateLimited() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 429)) { error in
            guard case TranscriptionError.rateLimited = error else {
                XCTFail("Expected rateLimited, got: \(error)")
                return
            }
        }
    }

    func testParseResponse_500_throwsServerError() {
        let json = #"{"error":{"message":"Internal server error"}}"#
        let data = Data(json.utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 500)) { error in
            guard case TranscriptionError.serverError(let statusCode, _) = error else {
                XCTFail("Expected serverError, got: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 500)
        }
    }

    func testParseResponse_400_throwsServerError() {
        let data = Data("{}".utf8)
        XCTAssertThrowsError(try service.parseResponse(data: data, statusCode: 400)) { error in
            guard case TranscriptionError.serverError(let statusCode, _) = error else {
                XCTFail("Expected serverError, got: \(error)")
                return
            }
            XCTAssertEqual(statusCode, 400)
        }
    }
}
