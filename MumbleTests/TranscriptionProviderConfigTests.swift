import XCTest
@testable import Mumble

final class TranscriptionProviderConfigTests: XCTestCase {

    private let userDefaultsKey = "com.mumble.transcriptionProviderConfig"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        super.tearDown()
    }

    func testLoad_withoutSavedConfig_returnsDefaultConfig() {
        let config = TranscriptionProviderConfig.load()

        XCTAssertEqual(config.selectedProvider, .groq)
        XCTAssertEqual(config.selectedModel(for: .groq).id, "whisper-large-v3")
        XCTAssertEqual(config.selectedModel(for: .fireworks).id, "whisper-v3-turbo")
        XCTAssertEqual(config.selectedModel(for: .elevenLabs).id, "scribe_v2")
        XCTAssertEqual(config.selectedModel(for: .deepgram).id, "nova-3")
        XCTAssertEqual(config.selectedModel(for: .assemblyAI).id, "universal-3-pro-fallback")
    }

    func testSaveAndLoad_roundTripsSelectedProviderAndModels() {
        var config = TranscriptionProviderConfig.default
        config.selectedProvider = .deepgram
        config.selectModel("whisper-large-v3-turbo", for: .groq)
        config.selectModel("nova-2", for: .deepgram)
        config.selectModel("universal-2", for: .assemblyAI)

        config.save()

        let loaded = TranscriptionProviderConfig.load()
        XCTAssertEqual(loaded.selectedProvider, .deepgram)
        XCTAssertEqual(loaded.selectedModel(for: .groq).id, "whisper-large-v3-turbo")
        XCTAssertEqual(loaded.selectedModel(for: .deepgram).id, "nova-2")
        XCTAssertEqual(loaded.selectedModel(for: .assemblyAI).id, "universal-2")
    }

    func testSelectedModel_withUnknownStoredID_fallsBackToProviderDefault() {
        let config = TranscriptionProviderConfig(
            selectedProvider: .fireworks,
            selectedModelIDs: [TranscriptionProvider.fireworks.rawValue: "not-a-real-model"]
        )

        XCTAssertEqual(config.selectedModel(for: .fireworks).id, "whisper-v3-turbo")
    }
}
