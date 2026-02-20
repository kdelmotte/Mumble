import Foundation

// MARK: - GroqTranscriptionService

/// Handles audio transcription through the Groq Whisper API, including multipart
/// request construction, response parsing, API key validation, and automatic
/// retry with exponential backoff for transient failures.
final class GroqTranscriptionService {

    static let shared = GroqTranscriptionService()

    // MARK: - Constants

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
    private let modelsEndpoint = URL(string: "https://api.groq.com/openai/v1/models")!
    private let defaultModel = "whisper-large-v3"

    private let apiClient = APIClient(defaultTimeout: 30)
    private let logger = STTLogger.shared

    private init() {}

    // MARK: - Public API

    /// Transcribes the provided audio data and returns the recognized text.
    /// - Parameter prompt: Optional prompt hint (e.g. vocabulary corrections) to bias Whisper towards correct spellings.
    func transcribe(audioData: Data, apiKey: String, prompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw TranscriptionError.noAPIKey
        }
        guard !audioData.isEmpty else {
            throw TranscriptionError.invalidAudioData
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        let body = buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            model: defaultModel,
            responseFormat: "json",
            prompt: prompt
        )

        let request = apiClient.buildRequest(
            url: endpoint,
            apiKey: apiKey,
            contentType: "multipart/form-data; boundary=\(boundary)",
            body: body
        )

        logger.debug("Sending transcription request (\(audioData.count) bytes of audio)")

        let data: Data
        let statusCode: Int

        do {
            (data, statusCode) = try await apiClient.execute(request)
        } catch let error as APIClientError {
            switch error {
            case .timeout:
                logger.error("Transcription request timed out")
                throw TranscriptionError.timeout
            default:
                logger.error("Network error during transcription: \(error.localizedDescription)")
                throw TranscriptionError.networkError(error)
            }
        }

        return try parseResponse(data: data, statusCode: statusCode)
    }

    /// Transcribes audio with automatic retry and exponential backoff for transient errors.
    /// - Parameter prompt: Optional prompt hint (e.g. vocabulary corrections) to bias Whisper towards correct spellings.
    func transcribeWithRetry(audioData: Data, apiKey: String, prompt: String? = nil, maxRetries: Int = 2) async throws -> String {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let text = try await transcribe(audioData: audioData, apiKey: apiKey, prompt: prompt)
                return text
            } catch let error as TranscriptionError {
                lastError = error

                // Do not retry on non-transient errors.
                switch error {
                case .noAPIKey, .invalidAPIKey, .invalidAudioData, .rateLimited, .decodingError, .timeout, .accessDenied:
                    logger.warning("Non-retryable transcription error: \(error.localizedDescription)")
                    throw error
                case .serverError(let statusCode, _) where statusCode < 500:
                    logger.warning("Non-retryable client error (\(statusCode)): \(error.localizedDescription)")
                    throw error
                case .serverError, .networkError:
                    // Transient – eligible for retry.
                    break
                }

                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
                    logger.info("Transient error on attempt \(attempt + 1)/\(maxRetries + 1). Retrying in \(Int(delay))s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Unexpected non-TranscriptionError – wrap and throw immediately.
                throw TranscriptionError.networkError(error)
            }
        }

        throw lastError ?? TranscriptionError.networkError(
            NSError(domain: "GroqTranscriptionService", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "All retry attempts exhausted"])
        )
    }

    /// Validates whether the given API key is accepted by Groq.
    @discardableResult
    func validateAPIKey(_ key: String) async throws -> Bool {
        guard !key.isEmpty else {
            throw TranscriptionError.noAPIKey
        }

        let request = apiClient.buildRequest(
            url: modelsEndpoint,
            method: "GET",
            apiKey: key,
            timeout: 15
        )

        let data: Data
        let statusCode: Int

        do {
            (data, statusCode) = try await apiClient.execute(request)
        } catch let error as APIClientError {
            switch error {
            case .timeout:
                throw TranscriptionError.timeout
            default:
                throw TranscriptionError.networkError(error)
            }
        }

        switch statusCode {
        case 200:
            logger.info("API key validated successfully")
            return true
        case 401:
            logger.warning("API key validation failed: invalid key")
            throw TranscriptionError.invalidAPIKey
        case 429:
            throw TranscriptionError.rateLimited(retryAfter: nil)
        case 403:
            logger.warning("API key validation failed: access denied (possible VPN/proxy block)")
            throw TranscriptionError.accessDenied
        case 500...599:
            let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
            throw TranscriptionError.serverError(statusCode: statusCode, message: message)
        default:
            let message = apiClient.extractErrorMessage(from: data) ?? "Unexpected status code"
            throw TranscriptionError.serverError(statusCode: statusCode, message: message)
        }
    }

    // MARK: - Private Helpers

    /// Parses the HTTP response from the transcription endpoint.
    func parseResponse(data: Data, statusCode: Int) throws -> String {
        logger.debug("Transcription response status: \(statusCode)")

        switch statusCode {
        case 200:
            do {
                let transcriptionResponse = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
                logger.info("Transcription successful (\(transcriptionResponse.text.count) characters)")
                return transcriptionResponse.text
            } catch {
                logger.error("Failed to decode transcription response: \(error.localizedDescription)")
                throw TranscriptionError.decodingError(error)
            }

        case 401:
            logger.warning("Transcription failed: invalid API key")
            throw TranscriptionError.invalidAPIKey

        case 429:
            logger.warning("Transcription rate limited")
            throw TranscriptionError.rateLimited(retryAfter: nil)

        case 403:
            logger.warning("Transcription failed: access denied (possible VPN/proxy block)")
            throw TranscriptionError.accessDenied

        case 500...599:
            let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
            logger.error("Server error \(statusCode): \(message)")
            throw TranscriptionError.serverError(statusCode: statusCode, message: message)

        default:
            let message = apiClient.extractErrorMessage(from: data) ?? "Unexpected error"
            logger.error("Unexpected status \(statusCode): \(message)")
            throw TranscriptionError.serverError(statusCode: statusCode, message: message)
        }
    }

    /// Builds a `multipart/form-data` body containing the audio file and text fields.
    func buildMultipartBody(
        boundary: String,
        audioData: Data,
        model: String,
        responseFormat: String,
        language: String? = nil,
        prompt: String? = nil
    ) -> Data {
        var body = Data()

        func append(_ string: String) {
            if let data = string.data(using: .utf8) {
                body.append(data)
            }
        }

        // Audio file field.
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"recording.wav\"\r\n")
        append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        append("\r\n")

        // Model field.
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(model)\r\n")

        // Response format field.
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n")
        append("\(responseFormat)\r\n")

        // Optional language field.
        if let language {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
            append("\(language)\r\n")
        }

        // Optional prompt field (vocabulary hints).
        if let prompt {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            append("\(prompt)\r\n")
        }

        // Temperature 0 reduces hallucinations on silent/quiet audio.
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n")
        append("0\r\n")

        // Closing boundary.
        append("--\(boundary)--\r\n")

        return body
    }
}
