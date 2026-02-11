// VocabularyReplacer.swift
// Mumble
//
// Stateless rule-based vocabulary replacement. Used when Smart Formatting is OFF
// (no LLM context awareness). Performs case-insensitive, word-boundary replacement
// of spoken→corrected pairs.

import Foundation

enum VocabularyReplacer {

    /// Applies all valid vocabulary entries to the text using case-insensitive,
    /// word-boundary regex replacement.
    static func apply(_ entries: [VocabularyEntry], to text: String) -> String {
        let valid = entries.filter(\.isValid)
        guard !valid.isEmpty else { return text }

        var result = text
        for entry in valid {
            let escaped = NSRegularExpression.escapedPattern(for: entry.spoken)
            guard let regex = try? NSRegularExpression(
                pattern: "\\b\(escaped)\\b",
                options: .caseInsensitive
            ) else { continue }

            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result)
            ) { _, _ in
                entry.corrected
            }
        }
        return result
    }
}

// MARK: - NSRegularExpression Helper

private extension NSRegularExpression {

    /// Replaces all matches using a closure that receives the match result and
    /// original string, returning the replacement string.
    func stringByReplacingMatches(
        in string: String,
        range: NSRange,
        using block: (NSTextCheckingResult, String) -> String
    ) -> String {
        let matches = self.matches(in: string, range: range)
        var result = string
        // Process matches in reverse order so ranges stay valid.
        for match in matches.reversed() {
            guard let swiftRange = Range(match.range, in: result) else { continue }
            let replacement = block(match, String(result[swiftRange]))
            result.replaceSubrange(swiftRange, with: replacement)
        }
        return result
    }
}
