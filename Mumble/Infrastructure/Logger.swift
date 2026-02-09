import Foundation
import os

// MARK: - Log Level

enum LogLevel: String, Comparable {
    case debug   = "DEBUG"
    case info    = "INFO"
    case warning = "WARNING"
    case error   = "ERROR"

    private var severity: Int {
        switch self {
        case .debug:   return 0
        case .info:    return 1
        case .warning: return 2
        case .error:   return 3
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.severity < rhs.severity
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String

    var formatted: String {
        let formatter = LogEntry.dateFormatter
        return "[\(formatter.string(from: timestamp))] [\(level.rawValue)] \(message)"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - STTLogger

final class STTLogger {

    static let shared = STTLogger()

    private let osLogger = os.Logger(subsystem: "com.mumble", category: "general")
    private let queue = DispatchQueue(label: "com.mumble.logger", qos: .utility)
    private var entries: [LogEntry] = []
    private let maxEntries = 100

    private init() {}

    // MARK: - Logging Methods

    func debug(_ message: String) {
        log(level: .debug, message: message)
    }

    func info(_ message: String) {
        log(level: .info, message: message)
    }

    func warning(_ message: String) {
        log(level: .warning, message: message)
    }

    func error(_ message: String) {
        log(level: .error, message: message)
    }

    // MARK: - Retrieve Entries

    /// Returns a snapshot of all stored log entries (newest last).
    func getEntries() -> [LogEntry] {
        queue.sync { entries }
    }

    /// Returns all stored log entries formatted as a single string, one entry per line.
    func formattedLogString() -> String {
        let snapshot = queue.sync { entries }
        return snapshot.map(\.formatted).joined(separator: "\n")
    }

    /// Clears all stored log entries.
    func clear() {
        queue.sync { entries.removeAll() }
    }

    // MARK: - Private Helpers

    private func log(level: LogLevel, message: String) {
        let entry = LogEntry(timestamp: Date(), level: level, message: message)

        queue.sync {
            entries.append(entry)
            if entries.count > maxEntries {
                entries.removeFirst(entries.count - maxEntries)
            }
        }

        switch level {
        case .debug:
            osLogger.debug("\(message, privacy: .public)")
        case .info:
            osLogger.info("\(message, privacy: .public)")
        case .warning:
            osLogger.warning("\(message, privacy: .public)")
        case .error:
            osLogger.error("\(message, privacy: .public)")
        }
    }
}
