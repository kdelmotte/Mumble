// VocabularyConfig.swift
// Mumble
//
// Data model and persistence for the user's custom vocabulary — spoken→corrected
// word pairs that fix recurring Whisper misspellings of proper nouns, brand names,
// and accent-affected words. Follows the ToneMappingConfig persistence pattern.

import Foundation

// MARK: - VocabularyEntry

/// A single spoken→corrected word pair.
struct VocabularyEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var spoken: String
    var corrected: String

    init(id: UUID = UUID(), spoken: String = "", corrected: String = "") {
        self.id = id
        self.spoken = spoken
        self.corrected = corrected
    }

    /// An entry is valid when both fields contain non-whitespace text.
    var isValid: Bool {
        !spoken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !corrected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - VocabularyConfig

/// Stores the user's custom vocabulary entries. Persisted via UserDefaults as JSON.
struct VocabularyConfig: Codable, Equatable {

    var entries: [VocabularyEntry]

    static let `default` = VocabularyConfig(entries: [])

    /// Only entries where both spoken and corrected are non-empty.
    var validEntries: [VocabularyEntry] {
        entries.filter(\.isValid)
    }

    /// An instruction block to append to the LLM system prompt, or `nil` when
    /// there are no valid entries.
    var llmPromptSection: String? {
        let valid = validEntries
        guard !valid.isEmpty else { return nil }

        let pairs = valid
            .map { "\"\($0.spoken)\" → \"\($0.corrected)\"" }
            .joined(separator: "\n")

        return """
        Custom vocabulary — the user has specified these corrections for words \
        that are frequently misspelled by speech-to-text. Use context to decide \
        whether each correction applies (e.g. don't replace "cloud" with "Claude" \
        when the speaker is clearly talking about cloud computing):
        \(pairs)
        """
    }

    // MARK: - Persistence

    private static let userDefaultsKey = "com.mumble.vocabularyConfig"

    /// Loads the persisted config, falling back to `.default`.
    static func load() -> VocabularyConfig {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(VocabularyConfig.self, from: data)
        else {
            return .default
        }
        return config
    }

    /// Persists this config to UserDefaults.
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: VocabularyConfig.userDefaultsKey)
        }
    }
}
