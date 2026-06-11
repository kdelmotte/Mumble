import Combine
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

final class TranscriptionHistoryStoreTests: XCTestCase {

    private let suiteName = "TranscriptionHistoryStoreTests"
    private let historyKey = "com.mumble.transcriptionHistory.tests"
    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    private var defaults: UserDefaults!
    private var store: TranscriptionHistoryStore!
    private var databaseDirectoryURL: URL!
    private var databaseURL: URL!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        databaseDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        databaseURL = databaseDirectoryURL.appendingPathComponent("history.sqlite")
        store = TranscriptionHistoryStore(
            userDefaults: defaults,
            userDefaultsKey: historyKey,
            retentionInterval: 7 * 24 * 60 * 60,
            databaseURL: databaseURL
        )
    }

    override func tearDown() {
        store = nil
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: databaseDirectoryURL)
        defaults = nil
        databaseDirectoryURL = nil
        databaseURL = nil
        super.tearDown()
    }

    func testMigration_importsLegacyEntriesAndRemovesDefaultsKey() throws {
        try seedLegacyEntries([
            makeEntry(text: "At cutoff", daysAgo: 7),
            makeEntry(text: "Fresh", daysAgo: 1),
            makeEntry(text: "Expired", daysAgo: 8),
        ])

        let entries = store.loadRecent(limit: 10, asOf: referenceDate)

        XCTAssertEqual(entries.map(\.text), [
            "Fresh",
            "At cutoff",
        ])
        XCTAssertNil(defaults.data(forKey: historyKey))
    }

    func testLoadRecent_returnsNewestFirstAndHonorsLimit() {
        store.append(
            "Oldest kept",
            createdAt: referenceDate.addingTimeInterval(-(6 * 24 * 60 * 60)),
            asOf: referenceDate
        )
        store.append(
            "Middle",
            createdAt: referenceDate.addingTimeInterval(-(2 * 24 * 60 * 60)),
            asOf: referenceDate
        )
        store.append(
            "Newest",
            createdAt: referenceDate,
            asOf: referenceDate
        )

        let entries = store.loadRecent(limit: 2, asOf: referenceDate)

        XCTAssertEqual(entries.map(\.text), [
            "Newest",
            "Middle",
        ])
        XCTAssertEqual(store.countRecent(asOf: referenceDate), 3)
    }

    func testAppend_trimsWhitespaceBeforeSaving() {
        store.append(
            "  hello world  ",
            createdAt: referenceDate,
            asOf: referenceDate
        )

        XCTAssertEqual(store.loadRecent(limit: 1, asOf: referenceDate).first?.text, "hello world")
    }

    func testPruneExpired_removesEntriesOlderThanSevenDays() throws {
        try seedLegacyEntries([
            makeEntry(text: "Recent", daysAgo: 1),
            makeEntry(text: "Expired", daysAgo: 8),
        ])

        store.pruneExpired(asOf: referenceDate)

        XCTAssertEqual(store.countRecent(asOf: referenceDate), 1)
        XCTAssertEqual(store.loadRecent(limit: 10, asOf: referenceDate).map(\.text), ["Recent"])
    }

    func testDelete_removesOnlyMatchingEntry() throws {
        let entryToKeep = makeEntry(text: "Keep", daysAgo: 1)
        let entryToDelete = makeEntry(text: "Delete me", daysAgo: 2)
        let expiredEntry = makeEntry(text: "Expired", daysAgo: 10)
        try seedLegacyEntries([expiredEntry, entryToDelete, entryToKeep])

        _ = store.loadRecent(limit: 10, asOf: referenceDate)
        store.delete(id: entryToDelete.id, asOf: referenceDate)

        let updatedEntries = store.loadRecent(limit: 10, asOf: referenceDate)
        XCTAssertEqual(updatedEntries.map(\.text), ["Keep"])
    }

    func testClear_removesAllPersistedEntries() {
        store.append(
            "Recover me",
            createdAt: referenceDate,
            asOf: referenceDate
        )

        store.clear()

        XCTAssertTrue(store.loadRecent(limit: 10, asOf: referenceDate).isEmpty)
        XCTAssertEqual(store.countRecent(asOf: referenceDate), 0)
        XCTAssertNil(defaults.data(forKey: historyKey))
    }

    private func seedLegacyEntries(_ entries: [TranscriptionHistoryEntry]) throws {
        let data = try JSONEncoder().encode(entries)
        defaults.set(data, forKey: historyKey)
    }

    private func makeEntry(text: String, daysAgo: TimeInterval) -> TranscriptionHistoryEntry {
        TranscriptionHistoryEntry(
            createdAt: referenceDate.addingTimeInterval(-(daysAgo * 24 * 60 * 60)),
            text: text
        )
    }
}

@MainActor
final class SettingsViewModelHistoryTests: XCTestCase {

    private var historyManager: MockHistoryManager!
    private var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        historyManager = MockHistoryManager()
        viewModel = SettingsViewModel(
            loginItemManager: LoginItemManager(),
            audioRecorder: AudioRecorder(),
            soundPlayer: SoundPlayer(),
            historyManager: historyManager,
            historyPageSize: 50,
            loadPersistedAPIKeysOnInit: false
        )
    }

    override func tearDown() {
        viewModel = nil
        historyManager = nil
        super.tearDown()
    }

    func testInit_doesNotLoadHistoryUntilRequested() {
        XCTAssertTrue(historyManager.loadLimits.isEmpty)
        XCTAssertEqual(historyManager.countRequests, 0)
        XCTAssertTrue(viewModel.historyEntries.isEmpty)
        XCTAssertEqual(viewModel.visibleHistoryLimit, 0)
    }

    func testLoadInitialHistory_loadsFirstPageAndSetsHasMoreHistory() {
        historyManager.storedEntries = makeEntries(count: 120)

        viewModel.loadInitialHistory()

        XCTAssertEqual(historyManager.loadLimits, [50])
        XCTAssertEqual(viewModel.visibleHistoryLimit, 50)
        XCTAssertEqual(viewModel.historyEntries.count, 50)
        XCTAssertEqual(viewModel.historyTotalCount, 120)
        XCTAssertTrue(viewModel.hasMoreHistory)
    }

    func testLoadMoreHistory_growsVisibleSlice() {
        historyManager.storedEntries = makeEntries(count: 120)

        viewModel.loadInitialHistory()
        viewModel.loadMoreHistory()

        XCTAssertEqual(historyManager.loadLimits, [50, 100])
        XCTAssertEqual(viewModel.visibleHistoryLimit, 100)
        XCTAssertEqual(viewModel.historyEntries.count, 100)
        XCTAssertEqual(viewModel.historyTotalCount, 120)
        XCTAssertTrue(viewModel.hasMoreHistory)
    }

    func testDeleteRecentTranscription_updatesHistoryState() {
        historyManager.storedEntries = makeEntries(count: 3)
        let deletedID = historyManager.storedEntries[1].id

        viewModel.loadInitialHistory()
        viewModel.deleteRecentTranscription(id: deletedID)
        pumpMainRunLoop()

        XCTAssertEqual(viewModel.historyEntries.count, 2)
        XCTAssertEqual(viewModel.historyTotalCount, 2)
        XCTAssertFalse(viewModel.historyEntries.contains(where: { $0.id == deletedID }))
    }

    func testClearRecentTranscriptions_updatesHistoryState() {
        historyManager.storedEntries = makeEntries(count: 60)

        viewModel.loadInitialHistory()
        viewModel.clearRecentTranscriptions()
        pumpMainRunLoop()

        XCTAssertTrue(viewModel.historyEntries.isEmpty)
        XCTAssertEqual(viewModel.historyTotalCount, 0)
        XCTAssertFalse(viewModel.hasMoreHistory)
    }

    func testHistoryRevisionReloadsCurrentVisibleSliceWithoutResettingLimit() {
        historyManager.storedEntries = makeEntries(count: 120)

        viewModel.loadInitialHistory()
        viewModel.loadMoreHistory()

        let newestEntry = TranscriptionHistoryEntry(
            createdAt: Date(timeIntervalSince1970: 2_000_000_000),
            text: "Newest revision entry"
        )
        historyManager.prepend(newestEntry)
        pumpMainRunLoop()

        XCTAssertEqual(viewModel.visibleHistoryLimit, 100)
        XCTAssertEqual(historyManager.loadLimits, [50, 100, 100])
        XCTAssertEqual(viewModel.historyEntries.first?.text, "Newest revision entry")
        XCTAssertEqual(viewModel.historyEntries.count, 100)
        XCTAssertEqual(viewModel.historyTotalCount, 121)
    }

    private func makeEntries(count: Int) -> [TranscriptionHistoryEntry] {
        (0..<count).map { index in
            TranscriptionHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 1_800_000_000 - Double(index)),
                text: "Entry \(index)"
            )
        }
    }

    private func pumpMainRunLoop() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }
}

@MainActor
private final class MockHistoryManager: TranscriptionHistoryManaging {
    var storedEntries: [TranscriptionHistoryEntry] = []
    var loadLimits: [Int] = []
    var countRequests = 0

    private let revisionSubject = CurrentValueSubject<Int, Never>(0)

    var historyRevisionPublisher: AnyPublisher<Int, Never> {
        revisionSubject.eraseToAnyPublisher()
    }

    func loadRecentTranscriptions(limit: Int) -> [TranscriptionHistoryEntry] {
        loadLimits.append(limit)
        return Array(
            storedEntries
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
        )
    }

    func countRecentTranscriptions() -> Int {
        countRequests += 1
        return storedEntries.count
    }

    func deleteRecentTranscription(id: TranscriptionHistoryEntry.ID) {
        storedEntries.removeAll { $0.id == id }
        revisionSubject.send(revisionSubject.value + 1)
    }

    func clearRecentTranscriptions() {
        storedEntries = []
        revisionSubject.send(revisionSubject.value + 1)
    }

    func prepend(_ entry: TranscriptionHistoryEntry) {
        storedEntries.insert(entry, at: 0)
        revisionSubject.send(revisionSubject.value + 1)
    }
}
