// LLMFormattingService.swift
// Mumble
//
// API client for Groq Chat Completions. Sends transcribed text through an LLM
// for intelligent formatting: filler removal, self-correction handling, grammar
// fixes, and context-aware styling. Falls back to rule-based ToneTransformer on
// any failure.

import Foundation

// MARK: - LLMFormattingError

/// Errors specific to the LLM formatting pipeline.
enum LLMFormattingError: LocalizedError {

    case noAPIKey
    case invalidResponse(statusCode: Int, message: String?)
    case emptyResponse
    case networkError(Error)
    case timeout
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured for LLM formatting."
        case .invalidResponse(let statusCode, let message):
            return "LLM API error \(statusCode): \(message ?? "Unknown error")"
        case .emptyResponse:
            return "LLM returned an empty response."
        case .networkError(let error):
            return "Network error during LLM formatting: \(error.localizedDescription)"
        case .timeout:
            return "LLM formatting request timed out."
        case .decodingError(let error):
            return "Failed to decode LLM response: \(error.localizedDescription)"
        }
    }
}

// MARK: - LLMFormattingService

/// Handles text formatting through the Groq Chat Completions API, mirroring
/// the patterns used by ``GroqTranscriptionService`` (singleton, URLSession,
/// Bearer auth, structured errors).
final class LLMFormattingService {

    static let shared = LLMFormattingService()

    // MARK: - Constants

    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "llama-3.3-70b-versatile"
    private let temperature: Double = 0.1
    private let maxTokens = 1024

    private let apiClient = APIClient(defaultTimeout: 5)
    private let logger = STTLogger.shared

    private init() {}

    // MARK: - Public API

    /// Formats the given transcript using the Groq Chat Completions API.
    ///
    /// - Parameters:
    ///   - transcript: The raw transcribed text to format.
    ///   - systemPrompt: A context-specific system prompt guiding the LLM's formatting.
    ///   - apiKey: A valid Groq API key.
    /// - Returns: The LLM-formatted text.
    /// - Throws: An ``LLMFormattingError`` describing what went wrong.
    func format(transcript: String, systemPrompt: String, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw LLMFormattingError.noAPIKey
        }

        let requestBody = try buildRequestBody(transcript: transcript, systemPrompt: systemPrompt)
        let request = apiClient.buildRequest(url: endpoint, apiKey: apiKey, body: requestBody)

        logger.debug("LLMFormattingService: sending formatting request (\(transcript.count) chars)")

        let data: Data
        let statusCode: Int

        do {
            (data, statusCode) = try await apiClient.execute(request)
        } catch let error as APIClientError {
            switch error {
            case .timeout:
                logger.warning("LLMFormattingService: request timed out")
                throw LLMFormattingError.timeout
            default:
                logger.warning("LLMFormattingService: network error - \(error.localizedDescription)")
                throw LLMFormattingError.networkError(error)
            }
        }

        return try parseResponse(data: data, statusCode: statusCode, originalTranscript: transcript)
    }

    // MARK: - Private Helpers

    /// Builds the JSON request body for the Chat Completions API.
    private func buildRequestBody(transcript: String, systemPrompt: String) throws -> Data {
        let body: [String: Any] = [
            "model": model,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": "Format this transcript:\n\n###TRANSCRIPT_START###\n\(transcript)\n###TRANSCRIPT_END###"]
            ]
        ]

        return try JSONSerialization.data(withJSONObject: body)
    }

    /// Parses the Chat Completions response and extracts the formatted text.
    private func parseResponse(data: Data, statusCode: Int, originalTranscript: String) throws -> String {
        logger.debug("LLMFormattingService: response status \(statusCode)")

        guard statusCode == 200 else {
            let message = apiClient.extractErrorMessage(from: data)
            logger.warning("LLMFormattingService: API error \(statusCode): \(message ?? "unknown")")
            throw LLMFormattingError.invalidResponse(
                statusCode: statusCode,
                message: message
            )
        }

        // Decode the Chat Completions response.
        let completionResponse: ChatCompletionResponse
        do {
            completionResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            logger.warning("LLMFormattingService: failed to decode response - \(error.localizedDescription)")
            throw LLMFormattingError.decodingError(error)
        }

        guard let content = completionResponse.choices.first?.message.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.warning("LLMFormattingService: empty response content")
            throw LLMFormattingError.emptyResponse
        }

        let formatted = content.trimmingCharacters(in: .whitespacesAndNewlines)
        try validateOutput(formatted, originalTranscript: originalTranscript)
        logger.info("LLMFormattingService: formatting complete (\(formatted.count) chars)")
        return formatted
    }

    /// Validates that the LLM output is a reasonable formatting of the input
    /// rather than a conversational response or hallucination.
    private func validateOutput(_ output: String, originalTranscript: String) throws {
        let outputWords = output.split(whereSeparator: { $0.isWhitespace }).count
        let inputWords = max(originalTranscript.split(whereSeparator: { $0.isWhitespace }).count, 1)

        if outputWords > inputWords * 3 {
            logger.warning(
                "LLMFormattingService: output too long (\(outputWords) words vs \(inputWords) input words), likely conversational response"
            )
            throw LLMFormattingError.emptyResponse
        }
    }

}

// MARK: - Chat Completion Response Models

/// Minimal Codable models for the Groq/OpenAI Chat Completions response.
private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}
