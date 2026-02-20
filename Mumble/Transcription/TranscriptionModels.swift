import Foundation

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
