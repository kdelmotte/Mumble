import Foundation

// MARK: - ToneTransformer

/// Applies tone-specific casing and punctuation rules to transcribed text.
///
/// The transformer is designed to work with text produced by a Whisper speech-to-text
/// model. Whisper typically returns partially punctuated output; the transformer
/// respects existing punctuation and only adds minimal adjustments when punctuation
/// is clearly missing.
final class ToneTransformer {

    // MARK: - Public API

    /// Transforms `text` according to the given `tone` profile.
    ///
    /// - Parameters:
    ///   - text: Raw transcribed text, possibly already punctuated by the model.
    ///   - tone: The target tone profile.
    /// - Returns: The text with tone-appropriate casing and punctuation applied.
    func transform(_ text: String, tone: ToneProfile) -> String {
        let trimmed = collapseWhitespace(text)
        guard !trimmed.isEmpty else { return trimmed }

        // Step 1 -- Split into sentences, inferring boundaries when punctuation is missing.
        let sentences = splitIntoSentences(trimmed)

        // Step 2 -- Apply tone-specific rules.
        switch tone {
        case .professional:
            return applyProfessionalTone(sentences)
        case .casual:
            return applyCasualTone(sentences)
        case .veryCasual:
            return applyVeryCasualTone(sentences)
        }
    }

    // MARK: - Sentence Splitting

    /// Splits text into individual sentence strings. The splitter handles two scenarios:
    ///
    /// 1. **Already punctuated** -- The text contains sentence-ending punctuation
    ///    (`.` `?` `!`) and is split on those boundaries.
    /// 2. **Unpunctuated** -- The text has no (or very little) ending punctuation. In
    ///    this case we use heuristic boundary detection to infer where one sentence ends
    ///    and the next begins, then annotate each sentence as a question or statement.
    private func splitIntoSentences(_ text: String) -> [Sentence] {
        // Check whether the text already contains meaningful punctuation.
        if textHasSufficientPunctuation(text) {
            return splitOnExistingPunctuation(text)
        } else {
            return splitUnpunctuatedText(text)
        }
    }

    /// Returns `true` when the text contains at least one sentence-ending punctuation
    /// mark (`.`, `?`, `!`) that is not the very last character (i.e. there is evidence
    /// of multi-sentence punctuation), OR when the text ends with punctuation. We use a
    /// generous threshold: if the text has *any* of these marks it is considered
    /// "punctuated" and we trust the existing structure.
    private func textHasSufficientPunctuation(_ text: String) -> Bool {
        let punctuationCharacters: Set<Character> = [".", "?", "!"]
        return text.contains(where: { punctuationCharacters.contains($0) })
    }

    /// Splits text that already contains sentence-ending punctuation into `Sentence`
    /// values, preserving the trailing punctuation on each sentence.
    private func splitOnExistingPunctuation(_ text: String) -> [Sentence] {
        // Regex: capture everything up to and including a sentence-ending punctuation
        // mark that is followed by a space or end-of-string. This keeps abbreviations
        // like "Dr." from splitting mid-sentence (they are usually followed by a
        // non-space character or uppercase letter immediately).
        var sentences: [Sentence] = []
        var remaining = text[text.startIndex...]

        // Pattern: greedily match up to (and including) a sentence ender followed by
        // whitespace or end-of-string.
        while !remaining.isEmpty {
            if let range = remaining.range(of: #"[.!?]+(?:\s|$)"#, options: .regularExpression) {
                let sentenceEnd = range.upperBound
                let raw = String(remaining[remaining.startIndex..<sentenceEnd])
                    .trimmingCharacters(in: .whitespaces)
                if !raw.isEmpty {
                    sentences.append(makeSentence(from: raw))
                }
                remaining = remaining[sentenceEnd...]
            } else {
                // No more sentence-ending punctuation; the rest is a trailing fragment.
                let raw = String(remaining).trimmingCharacters(in: .whitespaces)
                if !raw.isEmpty {
                    sentences.append(makeSentence(from: raw))
                }
                break
            }
        }

        return sentences
    }

    /// Infers sentence boundaries in text that has no punctuation, returning annotated
    /// `Sentence` values with `isQuestion` set based on heuristics.
    private func splitUnpunctuatedText(_ text: String) -> [Sentence] {
        let words = text.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return [] }

        // We scan for "sentence-start" words. When we encounter one after at least a
        // few words of the current sentence we treat it as a new sentence boundary.
        var sentences: [Sentence] = []
        var currentWords: [String] = []

        for word in words {
            let lower = word.lowercased()

            // Consider starting a new sentence when:
            // - The current accumulator already has 3+ words (avoid splitting too early).
            // - The current word looks like it starts a new thought.
            if currentWords.count >= 3 && isSentenceStarter(lower) {
                let raw = currentWords.joined(separator: " ")
                sentences.append(annotateSentence(raw))
                currentWords = [word]
            } else {
                currentWords.append(word)
            }
        }

        // Flush remaining words.
        if !currentWords.isEmpty {
            let raw = currentWords.joined(separator: " ")
            sentences.append(annotateSentence(raw))
        }

        return sentences
    }

    // MARK: - Sentence Annotation

    /// Wraps a raw string (which may or may not end with punctuation) into a `Sentence`.
    private func makeSentence(from raw: String) -> Sentence {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let isQuestion = trimmed.hasSuffix("?")
        return Sentence(text: trimmed, isQuestion: isQuestion)
    }

    /// Annotates an unpunctuated string as a question or statement based on its opening
    /// words.
    private func annotateSentence(_ raw: String) -> Sentence {
        let isQuestion = looksLikeQuestion(raw)
        return Sentence(text: raw, isQuestion: isQuestion)
    }

    // MARK: - Question Detection

    /// Words/phrases that commonly open a question when they appear at the start of a
    /// clause.
    private static let questionStarters: Set<String> = [
        "who", "what", "where", "when", "why", "how",
        "are", "is", "do", "does", "did",
        "can", "could", "would", "will", "shall",
        "have", "has", "had",
        "were", "was", "am",
        "isn't", "aren't", "doesn't", "don't", "didn't",
        "won't", "wouldn't", "couldn't", "shouldn't",
        "haven't", "hasn't"
    ]

    /// Returns `true` when the raw sentence text looks like a question based on the
    /// first few words.
    private func looksLikeQuestion(_ text: String) -> Bool {
        let words = text.lowercased()
            .split(separator: " ")
            .prefix(3)
            .map(String.init)
        guard let first = words.first else { return false }

        // Direct question opener.
        if Self.questionStarters.contains(first) {
            return true
        }

        // Handle patterns like "hey are you ..." where a greeting precedes the question
        // word.
        if words.count >= 2 {
            let second = words[1]
            if Self.greetingWords.contains(first) && Self.questionStarters.contains(second) {
                return true
            }
        }

        return false
    }

    // MARK: - Sentence Boundary Heuristics

    /// Words that commonly begin a brand-new sentence in casual speech.
    ///
    /// This list is intentionally conservative. Words like "if", "the", "that", "this",
    /// "you", and "for" appear mid-sentence too often to be reliable sentence starters
    /// and are excluded to avoid over-splitting.
    private static let sentenceStarterWords: Set<String> = [
        "let's", "lets",
        "i'll", "i'm", "i've", "i'd",
        "we'll", "we're", "we've",
        "he's", "he'll",
        "she's", "she'll",
        "they're", "they'll", "they've",
        "it's", "it'll",
        "you're", "you'll", "you've",
        "but", "so", "also", "maybe",
        "please", "just", "actually", "anyway",
        "thanks", "thank", "okay", "ok", "sure", "yeah", "yes",
        "don't", "doesn't", "didn't", "won't", "wouldn't", "couldn't"
    ]

    private static let greetingWords: Set<String> = [
        "hey", "hi", "hello", "yo", "sup"
    ]

    /// Returns `true` when `word` (already lowercased) is a plausible sentence opener.
    private func isSentenceStarter(_ word: String) -> Bool {
        Self.sentenceStarterWords.contains(word)
    }

    // MARK: - Professional Tone

    /// Common contractions mapped to their expanded forms.
    private static let contractionExpansions: [(pattern: String, replacement: String)] = [
        ("won't", "will not"),
        ("can't", "cannot"),
        ("shan't", "shall not"),
        ("n't", " not"),
        ("I'm", "I am"),
        ("you're", "you are"),
        ("we're", "we are"),
        ("they're", "they are"),
        ("he's", "he is"),
        ("she's", "she is"),
        ("it's", "it is"),
        ("that's", "that is"),
        ("there's", "there is"),
        ("here's", "here is"),
        ("what's", "what is"),
        ("who's", "who is"),
        ("where's", "where is"),
        ("when's", "when is"),
        ("how's", "how is"),
        ("I've", "I have"),
        ("you've", "you have"),
        ("we've", "we have"),
        ("they've", "they have"),
        ("I'll", "I will"),
        ("you'll", "you will"),
        ("we'll", "we will"),
        ("they'll", "they will"),
        ("he'll", "he will"),
        ("she'll", "she will"),
        ("it'll", "it will"),
        ("I'd", "I would"),
        ("you'd", "you would"),
        ("we'd", "we would"),
        ("they'd", "they would"),
        ("he'd", "he would"),
        ("she'd", "she would"),
        ("it'd", "it would"),
        ("let's", "let us"),
    ]

    /// Expands common contractions in the given text to their formal equivalents.
    private func expandContractions(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in Self.contractionExpansions {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .caseInsensitive
            )
        }
        return result
    }

    /// Applies professional-tone rules:
    /// - Expand common contractions to their full forms.
    /// - Capitalize the first letter of each sentence.
    /// - Ensure every sentence ends with proper punctuation.
    /// - Capitalize standalone "i" to "I" throughout.
    private func applyProfessionalTone(_ sentences: [Sentence]) -> String {
        let transformed = sentences.map { sentence -> String in
            var s = sentence.text

            // Expand contractions first (before stripping punctuation).
            s = expandContractions(s)

            // Strip any existing trailing punctuation so we can re-apply it uniformly.
            let (body, existingPunctuation) = stripTrailingPunctuation(s)
            s = body

            // Capitalize standalone "i" to "I".
            s = capitalizePronounI(s)

            // Capitalize the first letter.
            s = capitalizeFirst(s)

            // Determine ending punctuation.
            let ending: String
            if !existingPunctuation.isEmpty {
                // Clean up dangling ellipsis — collapse to a single period.
                if existingPunctuation.allSatisfy({ $0 == "." }) && existingPunctuation.count > 1 {
                    ending = "."
                } else {
                    ending = existingPunctuation
                }
            } else if sentence.isQuestion {
                ending = "?"
            } else {
                ending = "."
            }

            return s + ending
        }

        return transformed.joined(separator: " ")
    }

    /// Capitalizes standalone "i" to "I" throughout the text using word-boundary matching.
    private func capitalizePronounI(_ text: String) -> String {
        // Match standalone "i" that is not part of a larger word.
        text.replacingOccurrences(
            of: #"\bi\b"#,
            with: "I",
            options: .regularExpression
        )
    }

    // MARK: - Casual Tone

    /// Applies casual-tone rules:
    /// - Capitalize the first letter of each sentence.
    /// - Ensure every sentence ends with proper punctuation.
    /// - Preserve existing contractions, question marks, and exclamation marks.
    private func applyCasualTone(_ sentences: [Sentence]) -> String {
        let transformed = sentences.map { sentence -> String in
            var s = sentence.text

            // Strip any existing trailing punctuation so we can re-apply it uniformly.
            let (body, existingPunctuation) = stripTrailingPunctuation(s)
            s = body

            // Capitalize the first letter.
            s = capitalizeFirst(s)

            // Determine ending punctuation.
            let ending: String
            if !existingPunctuation.isEmpty {
                ending = existingPunctuation
            } else if sentence.isQuestion {
                ending = "?"
            } else {
                ending = "."
            }

            return s + ending
        }

        return transformed.joined(separator: " ")
    }

    // MARK: - Very Casual Tone

    /// Applies very-casual-tone rules:
    /// - Lowercase the first letter of each sentence (unless it looks like a proper noun,
    ///   "I", or an acronym).
    /// - Remove the trailing period from the *last* sentence; keep internal punctuation.
    /// - Preserve question marks (they carry meaning).
    /// - Preserve contractions.
    private func applyVeryCasualTone(_ sentences: [Sentence]) -> String {
        let transformed: [String] = sentences.enumerated().map { index, sentence in
            var s = sentence.text
            let isLast = index == sentences.count - 1

            // Strip trailing punctuation so we can decide what to keep.
            let (body, existingPunctuation) = stripTrailingPunctuation(s)
            s = body

            // Lowercase the first character unless it should stay uppercase.
            s = lowercaseFirstUnlessProper(s)

            // Determine ending punctuation.
            let ending: String
            if sentence.isQuestion || existingPunctuation.contains("?") {
                ending = "?"
            } else if existingPunctuation.contains("!") {
                ending = "!"
            } else if isLast {
                // Drop trailing period on the last sentence for a casual feel.
                ending = ""
            } else {
                // Internal sentences keep their period for readability.
                ending = existingPunctuation.isEmpty ? "" : existingPunctuation
            }

            return s + ending
        }

        return transformed.joined(separator: " ")
    }

    // MARK: - Casing Helpers

    /// Capitalizes the first letter of `text` while leaving the rest unchanged.
    private func capitalizeFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// Lowercases the first letter of `text` unless it looks like a proper noun, the
    /// pronoun "I", or an acronym (two or more consecutive uppercase letters).
    private func lowercaseFirstUnlessProper(_ text: String) -> String {
        guard let first = text.first, first.isUppercase else { return text }

        let rest = text.dropFirst()

        // "I" standing alone or followed by "'".
        if first == "I" && (rest.isEmpty || rest.first == "'" || rest.first == " ") {
            return text
        }

        // Acronym heuristic: if the second character is also uppercase, keep it.
        if let second = rest.first, second.isUppercase {
            return text
        }

        return first.lowercased() + rest
    }

    // MARK: - Punctuation Helpers

    /// Strips sentence-ending punctuation (`.` `?` `!` and combinations like `...`) from
    /// the end of `text`, returning the body and the stripped punctuation separately.
    private func stripTrailingPunctuation(_ text: String) -> (body: String, punctuation: String) {
        var body = text[text.startIndex...]
        var punctuation = ""

        while let last = body.last, last == "." || last == "?" || last == "!" {
            punctuation = String(last) + punctuation
            body = body.dropLast()
        }

        let trimmedBody = String(body).trimmingCharacters(in: .whitespaces)
        return (trimmedBody, punctuation)
    }

    // MARK: - Whitespace Helpers

    /// Collapses runs of whitespace into single spaces and trims leading/trailing whitespace.
    private func collapseWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

// MARK: - Sentence (Internal Model)

/// A lightweight value that pairs a sentence's raw text with metadata inferred during
/// the splitting phase.
private struct Sentence {
    /// The raw text of the sentence (may still contain trailing punctuation at this stage).
    let text: String

    /// `true` when the sentence has been identified as a question, either by explicit
    /// punctuation or by heuristic analysis.
    let isQuestion: Bool
}
