import XCTest
@testable import Mumble

final class ProviderKeychainManagerTests: XCTestCase {

    private var manager: KeychainManager!

    override func setUp() {
        super.setUp()
        manager = KeychainManager(service: "com.mumble.test.providers", account: "api-key")
    }

    override func tearDown() {
        for provider in TranscriptionProvider.allCases {
            try? manager.deleteAPIKey(for: provider)
        }
        manager = nil
        super.tearDown()
    }

    func testSaveAndGet_allProviderSpecificKeys_doNotCollide() throws {
        let keysByProvider: [TranscriptionProvider: String] = [
            .groq: "gsk_test123",
            .fireworks: "fireworks_test456",
            .elevenLabs: "elevenlabs_test789",
            .deepgram: "deepgram_test012",
            .assemblyAI: "assemblyai_test345"
        ]

        for (provider, key) in keysByProvider {
            try manager.saveAPIKey(key, for: provider)
        }

        for (provider, expectedKey) in keysByProvider {
            XCTAssertEqual(manager.getAPIKey(for: provider), expectedKey)
        }

        XCTAssertEqual(manager.getAPIKey(), "gsk_test123")
    }

    func testDelete_providerSpecificKey_doesNotRemoveOtherProviders() throws {
        try manager.saveAPIKey("gsk_test123", for: .groq)
        try manager.saveAPIKey("deepgram_test456", for: .deepgram)
        try manager.saveAPIKey("assemblyai_test789", for: .assemblyAI)

        try manager.deleteAPIKey(for: .deepgram)

        XCTAssertEqual(manager.getAPIKey(for: .groq), "gsk_test123")
        XCTAssertNil(manager.getAPIKey(for: .deepgram))
        XCTAssertEqual(manager.getAPIKey(for: .assemblyAI), "assemblyai_test789")
    }

    func testLegacyDefaultAccount_isUsedForGroqProvider() throws {
        try manager.saveAPIKey("legacy-groq-key")

        XCTAssertEqual(manager.getAPIKey(for: .groq), "legacy-groq-key")
    }
}
