import XCTest
@testable import Mumble

final class ProviderTranscriptionServiceTests: XCTestCase {

    private let boundary = "TestBoundary-6789"
    private let sampleAudio = Data([0x52, 0x49, 0x46, 0x46])

    func testFireworksMultipartBody_containsModelAndPrompt() {
        let service = FireworksTranscriptionService.shared

        let body = service.buildMultipartBody(
            boundary: boundary,
            audioData: sampleAudio,
            model: "whisper-v3-turbo",
            prompt: "product names"
        )

        let bodyString = String(data: body, encoding: .utf8)!
        XCTAssertTrue(bodyString.contains("name=\"model\""))
        XCTAssertTrue(bodyString.contains("whisper-v3-turbo"))
        XCTAssertTrue(bodyString.contains("name=\"prompt\""))
        XCTAssertTrue(bodyString.contains("product names"))
    }

    func testDeepgramEndpointURL_includesModelAndSmartFormat() {
        let service = DeepgramTranscriptionService.shared
        let model = TranscriptionProvider.deepgram.modelOption(id: "nova-3")

        let url = service.buildEndpointURL(model: model)
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        XCTAssertEqual(components?.scheme, "https")
        XCTAssertEqual(components?.host, "api.deepgram.com")
        XCTAssertEqual(components?.path, "/v1/listen")
        XCTAssertTrue(components?.queryItems?.contains(where: { $0.name == "model" && $0.value == "nova-3" }) == true)
        XCTAssertTrue(components?.queryItems?.contains(where: { $0.name == "smart_format" && $0.value == "true" }) == true)
    }
}
