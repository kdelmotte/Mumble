import Foundation

// MARK: - ToneProfile

/// Represents the voice/tone that should be applied to dictated text before it is
/// inserted into the target application.
enum ToneProfile: String, CaseIterable, Codable, Sendable {

    /// Formal tone with expanded contractions, proper capitalization, and complete punctuation.
    case professional

    /// Standard conversational tone with proper capitalization and punctuation.
    case casual

    /// Relaxed, texting-style tone with lowercase starts and lighter punctuation.
    case veryCasual

    // MARK: - Display Properties

    /// A user-facing name suitable for menus and settings UI.
    var displayName: String {
        switch self {
        case .professional: return "Professional"
        case .casual:       return "Casual"
        case .veryCasual:   return "Very Casual"
        }
    }

    /// A brief description of what this tone does to dictated text.
    var description: String {
        switch self {
        case .professional:
            return "Formal capitalization, complete punctuation, and proper sentence structure."
        case .casual:
            return "Proper capitalization and punctuation, natural and conversational."
        case .veryCasual:
            return "Lowercase, lighter punctuation -- like texting a friend."
        }
    }
}

// MARK: - Tone Selection by App Context

/// Determines the appropriate tone profile for a given application context
/// by reading from the user's persisted `ToneMappingConfig`.
///
/// - Parameter context: The current foreground application context.
/// - Returns: The `ToneProfile` best suited to the context.
func toneForApp(_ context: AppContext) -> ToneProfile {
    let config = ToneMappingConfig.load()

    guard let bundleID = context.bundleIdentifier else {
        return config.other
    }

    let group = AppGroup.group(for: bundleID)
    return config.tone(for: group)
}
