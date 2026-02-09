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
    private let defaultModel = "whisper-large-v3-turbo"
    private let requestTimeoutInterval: TimeInterval = 30

    private let logger = STTLogger.shared

    private init() {}

    // MARK: - Public API

    /// Transcribes the provided audio data and returns the recognized text.
    ///
    /// - Parameters:
    ///   - audioData: Raw WAV audio bytes to transcribe.
    ///   - apiKey: A valid Groq API key.
    /// - Returns: The transcribed text.
    /// - Throws: A ``TranscriptionError`` describing what went wrong.
    func transcribe(audioData: Data, apiKey: String) async throws -> String {
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
            responseFormat: "json"
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeoutInterval
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        logger.debug("Sending transcription request (\(audioData.count) bytes of audio)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            logger.error("Transcription request timed out")
            throw TranscriptionError.timeout
        } catch {
            logger.error("Network error during transcription: \(error.localizedDescription)")
            throw TranscriptionError.networkError(error)
        }

        return try parseResponse(data: data, response: response)
    }

    /// Transcribes audio with automatic retry and exponential backoff for transient errors.
    ///
    /// Retries are attempted for server errors (5xx) and network errors only.
    /// Client errors such as 401 (invalid key) and 429 (rate limited) are thrown
    /// immediately without retrying.
    ///
    /// - Parameters:
    ///   - audioData: Raw WAV audio bytes to transcribe.
    ///   - apiKey: A valid Groq API key.
    ///   - maxRetries: Maximum number of retry attempts (default 2, meaning up to 3 total attempts).
    /// - Returns: The transcribed text.
    /// - Throws: A ``TranscriptionError`` if all attempts fail.
    func transcribeWithRetry(audioData: Data, apiKey: String, maxRetries: Int = 2) async throws -> String {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let text = try await transcribe(audioData: audioData, apiKey: apiKey)
                return text
            } catch let error as TranscriptionError {
                lastError = error

                // Do not retry on non-transient errors.
                switch error {
                case .noAPIKey, .invalidAPIKey, .invalidAudioData, .rateLimited, .decodingError, .timeout:
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
    ///
    /// This sends a lightweight GET request to the models listing endpoint which
    /// requires authentication but costs no credits.
    ///
    /// - Parameter key: The API key to validate.
    /// - Returns: `true` if the key is valid.
    /// - Throws: A ``TranscriptionError`` if the key is invalid or the request fails.
    @discardableResult
    func validateAPIKey(_ key: String) async throws -> Bool {
        guard !key.isEmpty else {
            throw TranscriptionError.noAPIKey
        }

        var request = URLRequest(url: modelsEndpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw TranscriptionError.timeout
        } catch {
            throw TranscriptionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError(
                NSError(domain: "GroqTranscriptionService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            )
        }

        switch httpResponse.statusCode {
        case 200:
            logger.info("API key validated successfully")
            return true
        case 401:
            logger.warning("API key validation failed: invalid key")
            throw TranscriptionError.invalidAPIKey
        case 429:
            let retryAfter = parseRetryAfter(from: httpResponse)
            throw TranscriptionError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            let message = extractErrorMessage(from: data) ?? "Internal server error"
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: message)
        default:
            let message = extractErrorMessage(from: data) ?? "Unexpected status code"
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    // MARK: - Private Helpers

    /// Parses the HTTP response from the transcription endpoint and returns the
    /// transcribed text, or throws an appropriate ``TranscriptionError``.
    private func parseResponse(data: Data, response: URLResponse) throws -> String {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.networkError(
                NSError(domain: "GroqTranscriptionService", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])
            )
        }

        logger.debug("Transcription response status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
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
            let retryAfter = parseRetryAfter(from: httpResponse)
            logger.warning("Transcription rate limited (retry after: \(retryAfter.map { "\($0)s" } ?? "unknown"))")
            throw TranscriptionError.rateLimited(retryAfter: retryAfter)

        case 500...599:
            let message = extractErrorMessage(from: data) ?? "Internal server error"
            logger.error("Server error \(httpResponse.statusCode): \(message)")
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: message)

        default:
            let message = extractErrorMessage(from: data) ?? "Unexpected error"
            logger.error("Unexpected status \(httpResponse.statusCode): \(message)")
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    /// Builds a `multipart/form-data` body containing the audio file and text fields.
    private func buildMultipartBody(
        boundary: String,
        audioData: Data,
        model: String,
        responseFormat: String,
        language: String? = nil
    ) -> Data {
        var body = Data()

        // Helper to append a UTF-8 string to the body buffer.
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

        // Closing boundary.
        append("--\(boundary)--\r\n")

        return body
    }

    /// Extracts the `Retry-After` header value as a `TimeInterval`, if present.
    private func parseRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let retryAfterValue = response.value(forHTTPHeaderField: "Retry-After") else {
            return nil
        }
        return TimeInterval(retryAfterValue)
    }

    /// Attempts to extract a human-readable error message from a JSON error response body.
    /// Groq errors typically follow the OpenAI format: `{ "error": { "message": "..." } }`.
    private func extractErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct ErrorBody: Decodable {
                let message: String
            }
            let error: ErrorBody
        }

        return try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.message
    }
}
