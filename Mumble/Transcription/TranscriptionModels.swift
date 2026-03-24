import Foundation
import SQLite3

// MARK: - Transcription Response

/// Represents the JSON response returned by the Groq Whisper transcription API.
struct TranscriptionResponse: Codable {
    let text: String
}

// MARK: - Transcription Request

/// Encapsulates the parameters needed to submit an audio transcription request.
struct TranscriptionRequest {
    /// Raw audio data (WAV format expected).
    let audioData: Data

    /// The Whisper model to use for transcription.
    let model: String

    /// Optional BCP-47 language code (e.g. "en") to guide transcription.
    let language: String?

    init(audioData: Data, model: String = "whisper-large-v3", language: String? = nil) {
        self.audioData = audioData
        self.model = model
        self.language = language
    }
}

// MARK: - Transcription History

/// A locally persisted, user-recoverable transcription snippet.
struct TranscriptionHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let text: String

    init(id: UUID = UUID(), createdAt: Date = Date(), text: String) {
        self.id = id
        self.createdAt = createdAt
        self.text = text
    }
}

/// Stores completed transcriptions from the last 7 days in a queryable SQLite database.
final class TranscriptionHistoryStore {
    private let userDefaults: UserDefaults
    private let legacyUserDefaultsKey: String
    private let retentionInterval: TimeInterval
    private let databaseURL: URL
    private let logger = STTLogger.shared
    private let queue = DispatchQueue(label: "com.mumble.transcriptionHistoryStore")

    private var database: OpaquePointer?
    private var hasPreparedDatabase = false

    init(
        userDefaults: UserDefaults = .standard,
        userDefaultsKey: String = "com.mumble.transcriptionHistory",
        retentionInterval: TimeInterval = 7 * 24 * 60 * 60,
        databaseURL: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.legacyUserDefaultsKey = userDefaultsKey
        self.retentionInterval = Swift.max(1, retentionInterval)
        self.databaseURL = databaseURL ?? Self.defaultDatabaseURL()
    }

    deinit {
        queue.sync {
            guard let database else { return }
            sqlite3_close(database)
        }
    }

    func loadRecent(limit: Int, asOf: Date = Date()) -> [TranscriptionHistoryEntry] {
        guard limit > 0 else { return [] }

        return queue.sync {
            guard prepareDatabaseIfNeeded(asOf: asOf) else { return [] }

            pruneExpiredLocked(asOf: asOf)

            let sql = """
                SELECT id, created_at, text
                FROM transcription_history
                WHERE created_at >= ?
                ORDER BY created_at DESC
                LIMIT ?;
                """

            guard let statement = prepareStatement(sql: sql) else { return [] }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, cutoffDate(for: asOf).timeIntervalSince1970)
            sqlite3_bind_int(statement, 2, Int32(min(limit, Int(Int32.max))))

            var entries: [TranscriptionHistoryEntry] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let idCString = sqlite3_column_text(statement, 0),
                    let textCString = sqlite3_column_text(statement, 2),
                    let id = UUID(uuidString: String(cString: idCString))
                else {
                    continue
                }

                let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 1))
                let text = String(cString: textCString)
                entries.append(TranscriptionHistoryEntry(id: id, createdAt: createdAt, text: text))
            }

            return entries
        }
    }

    func countRecent(asOf: Date = Date()) -> Int {
        queue.sync {
            guard prepareDatabaseIfNeeded(asOf: asOf) else { return 0 }

            pruneExpiredLocked(asOf: asOf)

            let sql = """
                SELECT COUNT(*)
                FROM transcription_history
                WHERE created_at >= ?;
                """

            guard let statement = prepareStatement(sql: sql) else { return 0 }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, cutoffDate(for: asOf).timeIntervalSince1970)

            guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int64(statement, 0))
        }
    }

    func append(_ text: String, createdAt: Date = Date(), asOf: Date = Date()) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }

        queue.sync {
            guard prepareDatabaseIfNeeded(asOf: asOf) else { return }

            pruneExpiredLocked(asOf: asOf)
            _ = insertEntryLocked(
                id: UUID(),
                createdAt: createdAt,
                text: trimmedText
            )
        }
    }

    func delete(id: TranscriptionHistoryEntry.ID, asOf: Date = Date()) {
        queue.sync {
            guard prepareDatabaseIfNeeded(asOf: asOf) else { return }

            pruneExpiredLocked(asOf: asOf)

            let sql = "DELETE FROM transcription_history WHERE id = ?;"
            guard let statement = prepareStatement(sql: sql) else { return }
            defer { sqlite3_finalize(statement) }

            bindText(id.uuidString, at: 1, into: statement)

            if sqlite3_step(statement) != SQLITE_DONE {
                logger.error("TranscriptionHistoryStore: failed deleting entry - \(lastErrorMessage())")
            }
        }
    }

    func clear() {
        queue.sync {
            guard prepareDatabaseIfNeeded(asOf: Date()) else {
                userDefaults.removeObject(forKey: legacyUserDefaultsKey)
                return
            }

            if sqlite3_exec(database, "DELETE FROM transcription_history;", nil, nil, nil) != SQLITE_OK {
                logger.error("TranscriptionHistoryStore: failed clearing history - \(lastErrorMessage())")
            }

            userDefaults.removeObject(forKey: legacyUserDefaultsKey)
        }
    }

    func pruneExpired(asOf: Date = Date()) {
        queue.sync {
            guard prepareDatabaseIfNeeded(asOf: asOf) else { return }
            pruneExpiredLocked(asOf: asOf)
        }
    }

    private func prepareDatabaseIfNeeded(asOf: Date) -> Bool {
        if hasPreparedDatabase { return database != nil }

        guard openDatabaseLocked() else { return false }
        guard createSchemaLocked() else { return false }

        migrateLegacyEntriesLocked(asOf: asOf)
        pruneExpiredLocked(asOf: asOf)

        hasPreparedDatabase = true
        return true
    }

    private func openDatabaseLocked() -> Bool {
        if database != nil { return true }

        do {
            try FileManager.default.createDirectory(
                at: databaseURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            logger.error("TranscriptionHistoryStore: failed creating database directory - \(error.localizedDescription)")
            return false
        }

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX

        if sqlite3_open_v2(databaseURL.path, &database, flags, nil) != SQLITE_OK {
            let message = database.flatMap { String(validatingUTF8: sqlite3_errmsg($0)) } ?? "unknown error"
            logger.error("TranscriptionHistoryStore: failed opening database - \(message)")
            if let database {
                sqlite3_close(database)
            }
            return false
        }

        self.database = database
        return true
    }

    private func createSchemaLocked() -> Bool {
        let sql = """
            CREATE TABLE IF NOT EXISTS transcription_history (
                id TEXT PRIMARY KEY NOT NULL,
                created_at REAL NOT NULL,
                text TEXT NOT NULL
            );
            CREATE INDEX IF NOT EXISTS transcription_history_created_at_idx
            ON transcription_history(created_at DESC);
            """

        if sqlite3_exec(database, sql, nil, nil, nil) != SQLITE_OK {
            logger.error("TranscriptionHistoryStore: failed creating schema - \(lastErrorMessage())")
            return false
        }

        return true
    }

    private func migrateLegacyEntriesLocked(asOf: Date) {
        guard let data = userDefaults.data(forKey: legacyUserDefaultsKey) else { return }

        let decoder = JSONDecoder()
        guard let entries = try? decoder.decode([TranscriptionHistoryEntry].self, from: data) else {
            logger.warning("TranscriptionHistoryStore: legacy history could not be decoded; leaving UserDefaults data in place")
            return
        }

        guard !entries.isEmpty else {
            userDefaults.removeObject(forKey: legacyUserDefaultsKey)
            return
        }

        guard sqlite3_exec(database, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) == SQLITE_OK else {
            logger.error("TranscriptionHistoryStore: failed beginning migration transaction - \(lastErrorMessage())")
            return
        }

        var migrationSucceeded = true
        for entry in entries {
            if !insertEntryLocked(id: entry.id, createdAt: entry.createdAt, text: entry.text) {
                migrationSucceeded = false
                break
            }
        }

        if migrationSucceeded {
            if sqlite3_exec(database, "COMMIT;", nil, nil, nil) != SQLITE_OK {
                logger.error("TranscriptionHistoryStore: failed committing migration - \(lastErrorMessage())")
                _ = sqlite3_exec(database, "ROLLBACK;", nil, nil, nil)
                return
            }

            userDefaults.removeObject(forKey: legacyUserDefaultsKey)
            pruneExpiredLocked(asOf: asOf)
            logger.info("TranscriptionHistoryStore: migrated \(entries.count) legacy history entries to SQLite")
        } else {
            logger.error("TranscriptionHistoryStore: failed migrating legacy history entries - \(lastErrorMessage())")
            _ = sqlite3_exec(database, "ROLLBACK;", nil, nil, nil)
        }
    }

    private func insertEntryLocked(id: UUID, createdAt: Date, text: String) -> Bool {
        let sql = """
            INSERT OR REPLACE INTO transcription_history (id, created_at, text)
            VALUES (?, ?, ?);
            """

        guard let statement = prepareStatement(sql: sql) else { return false }
        defer { sqlite3_finalize(statement) }

        bindText(id.uuidString, at: 1, into: statement)
        sqlite3_bind_double(statement, 2, createdAt.timeIntervalSince1970)
        bindText(text, at: 3, into: statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            logger.error("TranscriptionHistoryStore: failed inserting entry - \(lastErrorMessage())")
            return false
        }

        return true
    }

    private func pruneExpiredLocked(asOf: Date) {
        let sql = "DELETE FROM transcription_history WHERE created_at < ?;"
        guard let statement = prepareStatement(sql: sql) else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, cutoffDate(for: asOf).timeIntervalSince1970)

        if sqlite3_step(statement) != SQLITE_DONE {
            logger.error("TranscriptionHistoryStore: failed pruning expired entries - \(lastErrorMessage())")
        }
    }

    private func prepareStatement(sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            logger.error("TranscriptionHistoryStore: failed preparing SQL - \(lastErrorMessage())")
            return nil
        }
        return statement
    }

    private func bindText(_ text: String, at index: Int32, into statement: OpaquePointer?) {
        _ = text.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, sqliteTransientDestructor)
        }
    }

    private func cutoffDate(for asOf: Date) -> Date {
        asOf.addingTimeInterval(-retentionInterval)
    }

    private func lastErrorMessage() -> String {
        guard let database else { return "unknown error" }
        return String(cString: sqlite3_errmsg(database))
    }

    private static func defaultDatabaseURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directoryName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Mumble"
        return baseURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent("TranscriptionHistory.sqlite", isDirectory: false)
    }
}

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Transcription Error

/// Errors that can occur during audio transcription via the Groq API.
enum TranscriptionError: LocalizedError {
    /// No API key has been configured.
    case noAPIKey

    /// The provided API key was rejected by the server (HTTP 401).
    case invalidAPIKey

    /// A network-level error occurred (DNS failure, no connectivity, etc.).
    case networkError(Error)

    /// The API rate limit has been exceeded. `retryAfter` contains the suggested
    /// wait duration in seconds when the server provides a `Retry-After` header.
    case rateLimited(retryAfter: TimeInterval?)

    /// The server returned a non-success status code outside the expected range.
    case serverError(statusCode: Int, message: String)

    /// The audio data supplied was empty or otherwise invalid.
    case invalidAudioData

    /// The response body could not be decoded into the expected model.
    case decodingError(Error)

    /// The request did not complete within the allotted time.
    case timeout

    /// The server returned HTTP 403, typically because Groq is blocking a VPN/proxy IP.
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Groq API key in Settings."
        case .invalidAPIKey:
            return "The API key is invalid or has been revoked. Please update your key in Settings."
        case .networkError(let underlying):
            return "A network error occurred: \(underlying.localizedDescription)"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limit exceeded. Please try again in \(Int(seconds)) seconds."
            }
            return "Rate limit exceeded. Please wait a moment and try again."
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .invalidAudioData:
            return "The audio data is empty or in an unsupported format."
        case .decodingError(let underlying):
            return "Failed to decode transcription response: \(underlying.localizedDescription)"
        case .timeout:
            return "The transcription request timed out. Please try again."
        case .accessDenied:
            return "Access denied (403). Groq blocks some VPN and proxy connections — try disconnecting your VPN or switching to a different server."
        }
    }
}
