// APIClient.swift
// Mumble
//
// Thin shared HTTP client for Mumble's speech/formatting provider calls.
// Centralises URLRequest construction, HTTP status checking, and JSON
// error parsing so provider-specific services only handle their own
// request/response details.

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
        buildRequest(
            url: url,
            method: method,
            headers: [
                "Authorization": "Bearer \(apiKey)",
                "Content-Type": contentType
            ],
            timeout: timeout,
            body: body
        )
    }

    /// Builds a URLRequest with fully custom headers.
    func buildRequest(
        url: URL,
        method: String = "POST",
        headers: [String: String],
        timeout: TimeInterval? = nil,
        body: Data? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? defaultTimeout
        request.httpBody = body

        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

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

    /// Attempts to extract a human-readable error message from common JSON
    /// error response shapes such as `{ "error": { "message": "..." } }`.
    func extractErrorMessage(from data: Data) -> String? {
        if
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            if
                let error = json["error"] as? [String: Any],
                let message = error["message"] as? String
            {
                return message
            }

            if let error = json["error"] as? String {
                return error
            }

            if
                let detail = json["detail"] as? [String: Any],
                let message = detail["message"] as? String
            {
                return message
            }

            if let detail = json["detail"] as? String {
                return detail
            }

            if let message = json["message"] as? String {
                return message
            }
        }

        return nil
    }
}
