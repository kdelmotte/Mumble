// APIClient.swift
// Mumble
//
// Thin shared HTTP client for Groq API calls. Centralises bearer auth,
// URLRequest construction, HTTP status checking, and JSON error parsing
// so that GroqTranscriptionService and LLMFormattingService only handle
// their service-specific request/response logic.

import Foundation

// MARK: - APIClientError

enum APIClientError: LocalizedError {
    case invalidHTTPResponse
    case timeout
    case networkError(Error)
    case httpError(statusCode: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse:
            return "Invalid HTTP response."
        case .timeout:
            return "Request timed out."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message ?? "Unknown error")"
        }
    }
}

// MARK: - APIClient

struct APIClient {

    /// Default timeout for API requests (can be overridden per-request).
    var defaultTimeout: TimeInterval = 30

    // MARK: - Request Building

    /// Builds an authenticated URLRequest for the given endpoint.
    func buildRequest(
        url: URL,
        method: String = "POST",
        apiKey: String,
        contentType: String = "application/json",
        timeout: TimeInterval? = nil,
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? defaultTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    // MARK: - Execution

    /// Sends a URLRequest and returns the raw response data along with the HTTP status code.
    /// Handles timeout detection and wraps transport errors.
    func execute(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            throw APIClientError.timeout
        } catch {
            throw APIClientError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidHTTPResponse
        }

        return (data, httpResponse.statusCode)
    }

    // MARK: - Error Parsing

    /// Attempts to extract a human-readable error message from a Groq/OpenAI
    /// JSON error response: `{ "error": { "message": "..." } }`.
    func extractErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct ErrorBody: Decodable {
                let message: String
            }
            let error: ErrorBody
        }
        return try? JSONDecoder().decode(ErrorEnvelope.self, from: data).error.message
    }
}
