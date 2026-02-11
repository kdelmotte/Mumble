import XCTest
@testable import Mumble

final class APIClientTests: XCTestCase {

    private var client: APIClient!
    private let testURL = URL(string: "https://api.example.com/v1/test")!
    private let testKey = "test-api-key-123"

    override func setUp() {
        super.setUp()
        client = APIClient()
    }

    override func tearDown() {
        client = nil
        super.tearDown()
    }

    // MARK: - Request Building: URL & Method

    func testBuildRequest_setsURL() {
        let request = client.buildRequest(url: testURL, apiKey: testKey)
        XCTAssertEqual(request.url, testURL)
    }

    func testBuildRequest_defaultsToPost() {
        let request = client.buildRequest(url: testURL, apiKey: testKey)
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testBuildRequest_customMethod() {
        let request = client.buildRequest(url: testURL, method: "GET", apiKey: testKey)
        XCTAssertEqual(request.httpMethod, "GET")
    }

    // MARK: - Request Building: Headers

    func testBuildRequest_setsAuthorizationHeader() {
        let request = client.buildRequest(url: testURL, apiKey: testKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(testKey)")
    }

    func testBuildRequest_defaultContentType() {
        let request = client.buildRequest(url: testURL, apiKey: testKey)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testBuildRequest_customContentType() {
        let request = client.buildRequest(
            url: testURL,
            apiKey: testKey,
            contentType: "multipart/form-data; boundary=abc"
        )
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "multipart/form-data; boundary=abc")
    }

    // MARK: - Request Building: Timeout

    func testBuildRequest_customTimeout() {
        let request = client.buildRequest(url: testURL, apiKey: testKey, timeout: 60)
        XCTAssertEqual(request.timeoutInterval, 60)
    }

    func testBuildRequest_usesDefaultTimeout_whenNil() {
        client.defaultTimeout = 15
        let request = client.buildRequest(url: testURL, apiKey: testKey, timeout: nil)
        XCTAssertEqual(request.timeoutInterval, 15)
    }

    // MARK: - Request Building: Body

    func testBuildRequest_setsBody() {
        let body = Data("test body".utf8)
        let request = client.buildRequest(url: testURL, apiKey: testKey, body: body)
        XCTAssertEqual(request.httpBody, body)
    }

    func testBuildRequest_nilBody() {
        let request = client.buildRequest(url: testURL, apiKey: testKey, body: nil)
        XCTAssertNil(request.httpBody)
    }

    // MARK: - Error Message Extraction

    func testExtractErrorMessage_validEnvelope_returnsMessage() {
        let json = #"{"error":{"message":"Rate limit exceeded"}}"#
        let data = Data(json.utf8)
        XCTAssertEqual(client.extractErrorMessage(from: data), "Rate limit exceeded")
    }

    func testExtractErrorMessage_malformedJSON_returnsNil() {
        let data = Data("not json".utf8)
        XCTAssertNil(client.extractErrorMessage(from: data))
    }

    func testExtractErrorMessage_missingErrorKey_returnsNil() {
        let json = #"{"status":"fail"}"#
        let data = Data(json.utf8)
        XCTAssertNil(client.extractErrorMessage(from: data))
    }

    func testExtractErrorMessage_emptyData_returnsNil() {
        XCTAssertNil(client.extractErrorMessage(from: Data()))
    }

    // MARK: - Error Descriptions

    func testAPIClientError_allCases_haveDescriptions() {
        let cases: [APIClientError] = [
            .invalidHTTPResponse,
            .timeout,
            .networkError(NSError(domain: "test", code: 1)),
            .httpError(statusCode: 500, message: "Server Error"),
            .httpError(statusCode: 400, message: nil)
        ]

        for error in cases {
            let description = error.errorDescription
            XCTAssertNotNil(description, "Error \(error) should have a description")
            XCTAssertFalse(description!.isEmpty, "Error \(error) should have a non-empty description")
        }
    }
}
