import Foundation

private struct MultipartFormDataBuilder {
    let boundary: String
    private(set) var body = Data()

    mutating func appendFile(name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    mutating func appendField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append("\(value)\r\n")
    }

    mutating func finish() -> Data {
        append("--\(boundary)--\r\n")
        return body
    }

    private mutating func append(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        body.append(data)
    }
}

enum TranscriptionValidationAudio {
    static var sampleWAV: Data {
        let sampleRate = 16_000
        let durationSeconds = 0.25
        let sampleCount = Int(Double(sampleRate) * durationSeconds)
        let bytesPerSample = 2
        let channelCount = 1
        let dataSize = sampleCount * bytesPerSample * channelCount

        var data = Data()

        func append<T>(_ value: T) {
            var littleEndian = value
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: [0x52, 0x49, 0x46, 0x46]) // RIFF
        append(UInt32(36 + dataSize))
        data.append(contentsOf: [0x57, 0x41, 0x56, 0x45]) // WAVE
        data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20]) // fmt
        append(UInt32(16))
        append(UInt16(1)) // PCM
        append(UInt16(channelCount))
        append(UInt32(sampleRate))
        append(UInt32(sampleRate * channelCount * bytesPerSample))
        append(UInt16(channelCount * bytesPerSample))
        append(UInt16(16)) // bits per sample
        data.append(contentsOf: [0x64, 0x61, 0x74, 0x61]) // data
        append(UInt32(dataSize))
        data.append(Data(count: dataSize))

        return data
    }
}

private struct DeepgramResponse: Decodable {
    struct Results: Decodable {
        struct Channel: Decodable {
            struct Alternative: Decodable {
                let transcript: String
            }

            let alternatives: [Alternative]
        }

        let channels: [Channel]
    }

    let results: Results
}

private struct AssemblyAIUploadResponse: Decodable {
    let upload_url: String
}

private struct AssemblyAISubmitResponse: Decodable {
    let id: String
}

private struct AssemblyAIPollResponse: Decodable {
    let status: String
    let text: String?
    let error: String?
}

private func mapClientError(_ error: APIClientError) -> TranscriptionError {
    switch error {
    case .timeout:
        return .timeout
    default:
        return .networkError(error)
    }
}

private func parseDirectTextResponse(data: Data, statusCode: Int, apiClient: APIClient) throws -> String {
    switch statusCode {
    case 200:
        do {
            return try JSONDecoder().decode(TranscriptionResponse.self, from: data).text
        } catch {
            throw TranscriptionError.decodingError(error)
        }
    case 401:
        throw TranscriptionError.invalidAPIKey
    case 403:
        throw TranscriptionError.accessDenied
    case 429:
        throw TranscriptionError.rateLimited(retryAfter: nil)
    case 500...599:
        let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
        throw TranscriptionError.serverError(statusCode: statusCode, message: message)
    default:
        let message = apiClient.extractErrorMessage(from: data) ?? "Unexpected error"
        throw TranscriptionError.serverError(statusCode: statusCode, message: message)
    }
}

// MARK: - FireworksTranscriptionService

final class FireworksTranscriptionService: AudioTranscriptionService {
    static let shared = FireworksTranscriptionService()

    let provider: TranscriptionProvider = .fireworks

    private let apiClient = APIClient(defaultTimeout: 30)
    private let logger = STTLogger.shared

    private init() {}

    @discardableResult
    func validateAPIKey(_ key: String, model: TranscriptionModelOption? = nil) async throws -> Bool {
        _ = try await transcribe(
            audioData: TranscriptionValidationAudio.sampleWAV,
            apiKey: key,
            model: model ?? provider.modelOption(id: provider.defaultModelID),
            prompt: nil
        )
        return true
    }

    func transcribe(
        audioData: Data,
        apiKey: String,
        model: TranscriptionModelOption,
        prompt: String?
    ) async throws -> String {
        _ = prompt

        guard !apiKey.isEmpty else { throw TranscriptionError.noAPIKey }
        guard !audioData.isEmpty else { throw TranscriptionError.invalidAudioData }

        let boundary = "Boundary-\(UUID().uuidString)"
        let body = buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            model: model.primaryRequestModelID,
            prompt: prompt
        )

        let request = apiClient.buildRequest(
            url: endpoint(for: model),
            headers: [
                "Authorization": apiKey,
                "Content-Type": "multipart/form-data; boundary=\(boundary)"
            ],
            body: body
        )

        logger.debug("Fireworks: sending transcription request")

        do {
            let (data, statusCode) = try await apiClient.execute(request)
            return try parseDirectTextResponse(data: data, statusCode: statusCode, apiClient: apiClient)
        } catch let error as APIClientError {
            throw mapClientError(error)
        }
    }

    func buildMultipartBody(
        boundary: String,
        audioData: Data,
        model: String,
        prompt: String?
    ) -> Data {
        var builder = MultipartFormDataBuilder(boundary: boundary)
        builder.appendFile(name: "file", filename: "recording.wav", mimeType: "audio/wav", data: audioData)
        builder.appendField(name: "model", value: model)
        builder.appendField(name: "response_format", value: "json")
        builder.appendField(name: "temperature", value: "0")
        if let prompt, !prompt.isEmpty {
            builder.appendField(name: "prompt", value: prompt)
        }
        return builder.finish()
    }

    private func endpoint(for model: TranscriptionModelOption) -> URL {
        switch model.primaryRequestModelID {
        case "whisper-v3-turbo":
            return URL(string: "https://audio-turbo.api.fireworks.ai/v1/audio/transcriptions")!
        default:
            return URL(string: "https://audio-prod.api.fireworks.ai/v1/audio/transcriptions")!
        }
    }
}

// MARK: - ElevenLabsTranscriptionService

final class ElevenLabsTranscriptionService: AudioTranscriptionService {
    static let shared = ElevenLabsTranscriptionService()

    let provider: TranscriptionProvider = .elevenLabs

    private let endpoint = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    private let apiClient = APIClient(defaultTimeout: 30)

    private init() {}

    @discardableResult
    func validateAPIKey(_ key: String, model: TranscriptionModelOption? = nil) async throws -> Bool {
        _ = try await transcribe(
            audioData: TranscriptionValidationAudio.sampleWAV,
            apiKey: key,
            model: model ?? provider.modelOption(id: provider.defaultModelID),
            prompt: nil
        )
        return true
    }

    func transcribe(
        audioData: Data,
        apiKey: String,
        model: TranscriptionModelOption,
        prompt: String?
    ) async throws -> String {
        _ = prompt

        guard !apiKey.isEmpty else { throw TranscriptionError.noAPIKey }
        guard !audioData.isEmpty else { throw TranscriptionError.invalidAudioData }

        let boundary = "Boundary-\(UUID().uuidString)"
        var builder = MultipartFormDataBuilder(boundary: boundary)
        builder.appendFile(name: "file", filename: "recording.wav", mimeType: "audio/wav", data: audioData)
        builder.appendField(name: "model_id", value: model.primaryRequestModelID)

        let request = apiClient.buildRequest(
            url: endpoint,
            headers: [
                "xi-api-key": apiKey,
                "Content-Type": "multipart/form-data; boundary=\(boundary)"
            ],
            body: builder.finish()
        )

        do {
            let (data, statusCode) = try await apiClient.execute(request)
            return try parseDirectTextResponse(data: data, statusCode: statusCode, apiClient: apiClient)
        } catch let error as APIClientError {
            throw mapClientError(error)
        }
    }
}

// MARK: - DeepgramTranscriptionService

final class DeepgramTranscriptionService: AudioTranscriptionService {
    static let shared = DeepgramTranscriptionService()

    let provider: TranscriptionProvider = .deepgram

    private let endpoint = URL(string: "https://api.deepgram.com/v1/listen")!
    private let apiClient = APIClient(defaultTimeout: 30)

    private init() {}

    @discardableResult
    func validateAPIKey(_ key: String, model: TranscriptionModelOption? = nil) async throws -> Bool {
        _ = try await transcribe(
            audioData: TranscriptionValidationAudio.sampleWAV,
            apiKey: key,
            model: model ?? provider.modelOption(id: provider.defaultModelID),
            prompt: nil
        )
        return true
    }

    func transcribe(
        audioData: Data,
        apiKey: String,
        model: TranscriptionModelOption,
        prompt: String?
    ) async throws -> String {
        _ = prompt

        guard !apiKey.isEmpty else { throw TranscriptionError.noAPIKey }
        guard !audioData.isEmpty else { throw TranscriptionError.invalidAudioData }

        let request = apiClient.buildRequest(
            url: buildEndpointURL(model: model),
            headers: [
                "Authorization": "Token \(apiKey)",
                "Content-Type": "audio/wav"
            ],
            body: audioData
        )

        do {
            let (data, statusCode) = try await apiClient.execute(request)
            return try parseResponse(data: data, statusCode: statusCode)
        } catch let error as APIClientError {
            throw mapClientError(error)
        }
    }

    func buildEndpointURL(model: TranscriptionModelOption) -> URL {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "model", value: model.primaryRequestModelID),
            URLQueryItem(name: "smart_format", value: "true")
        ]
        return components?.url ?? endpoint
    }

    private func parseResponse(data: Data, statusCode: Int) throws -> String {
        switch statusCode {
        case 200:
            do {
                let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
                return response.results.channels.first?.alternatives.first?.transcript ?? ""
            } catch {
                throw TranscriptionError.decodingError(error)
            }
        case 401:
            throw TranscriptionError.invalidAPIKey
        case 403:
            throw TranscriptionError.accessDenied
        case 429:
            throw TranscriptionError.rateLimited(retryAfter: nil)
        case 500...599:
            let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
            throw TranscriptionError.serverError(statusCode: statusCode, message: message)
        default:
            let message = apiClient.extractErrorMessage(from: data) ?? "Unexpected error"
            throw TranscriptionError.serverError(statusCode: statusCode, message: message)
        }
    }
}

// MARK: - AssemblyAITranscriptionService

final class AssemblyAITranscriptionService: AudioTranscriptionService {
    static let shared = AssemblyAITranscriptionService()

    let provider: TranscriptionProvider = .assemblyAI

    private let uploadEndpoint = URL(string: "https://api.assemblyai.com/v2/upload")!
    private let transcriptEndpoint = URL(string: "https://api.assemblyai.com/v2/transcript")!
    private let apiClient = APIClient(defaultTimeout: 30)

    private init() {}

    @discardableResult
    func validateAPIKey(_ key: String, model: TranscriptionModelOption? = nil) async throws -> Bool {
        guard !key.isEmpty else { throw TranscriptionError.noAPIKey }

        let request = apiClient.buildRequest(
            url: uploadEndpoint,
            headers: [
                "authorization": key,
                "Content-Type": "application/octet-stream"
            ],
            body: TranscriptionValidationAudio.sampleWAV
        )

        do {
            let (_, statusCode) = try await apiClient.execute(request)
            switch statusCode {
            case 200:
                return true
            case 401:
                throw TranscriptionError.invalidAPIKey
            case 403:
                throw TranscriptionError.accessDenied
            case 429:
                throw TranscriptionError.rateLimited(retryAfter: nil)
            case 500...599:
                throw TranscriptionError.serverError(statusCode: statusCode, message: "Internal server error")
            default:
                throw TranscriptionError.serverError(statusCode: statusCode, message: "Unexpected upload response")
            }
        } catch let error as APIClientError {
            throw mapClientError(error)
        }
    }

    func transcribe(
        audioData: Data,
        apiKey: String,
        model: TranscriptionModelOption,
        prompt: String?
    ) async throws -> String {
        _ = prompt

        guard !apiKey.isEmpty else { throw TranscriptionError.noAPIKey }
        guard !audioData.isEmpty else { throw TranscriptionError.invalidAudioData }

        let uploadURL = try await uploadAudio(audioData: audioData, apiKey: apiKey)
        let transcriptID = try await submitTranscript(uploadURL: uploadURL, apiKey: apiKey, model: model)
        return try await pollTranscript(id: transcriptID, apiKey: apiKey)
    }

    private func uploadAudio(audioData: Data, apiKey: String) async throws -> String {
        let request = apiClient.buildRequest(
            url: uploadEndpoint,
            headers: [
                "authorization": apiKey,
                "Content-Type": "application/octet-stream"
            ],
            body: audioData
        )

        do {
            let (data, statusCode) = try await apiClient.execute(request)

            switch statusCode {
            case 200:
                return try JSONDecoder().decode(AssemblyAIUploadResponse.self, from: data).upload_url
            case 401:
                throw TranscriptionError.invalidAPIKey
            case 403:
                throw TranscriptionError.accessDenied
            case 429:
                throw TranscriptionError.rateLimited(retryAfter: nil)
            case 500...599:
                let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
                throw TranscriptionError.serverError(statusCode: statusCode, message: message)
            default:
                let message = apiClient.extractErrorMessage(from: data) ?? "Upload failed"
                throw TranscriptionError.serverError(statusCode: statusCode, message: message)
            }
        } catch let error as APIClientError {
            throw mapClientError(error)
        } catch let error as DecodingError {
            throw TranscriptionError.decodingError(error)
        }
    }

    private func submitTranscript(uploadURL: String, apiKey: String, model: TranscriptionModelOption) async throws -> String {
        let body = try JSONSerialization.data(withJSONObject: [
            "audio_url": uploadURL,
            "speech_models": model.requestModelIDs,
            "language_detection": true
        ])

        let request = apiClient.buildRequest(
            url: transcriptEndpoint,
            headers: [
                "authorization": apiKey,
                "Content-Type": "application/json"
            ],
            body: body
        )

        do {
            let (data, statusCode) = try await apiClient.execute(request)

            switch statusCode {
            case 200:
                return try JSONDecoder().decode(AssemblyAISubmitResponse.self, from: data).id
            case 401:
                throw TranscriptionError.invalidAPIKey
            case 403:
                throw TranscriptionError.accessDenied
            case 429:
                throw TranscriptionError.rateLimited(retryAfter: nil)
            case 500...599:
                let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
                throw TranscriptionError.serverError(statusCode: statusCode, message: message)
            default:
                let message = apiClient.extractErrorMessage(from: data) ?? "Submit failed"
                throw TranscriptionError.serverError(statusCode: statusCode, message: message)
            }
        } catch let error as APIClientError {
            throw mapClientError(error)
        } catch let error as DecodingError {
            throw TranscriptionError.decodingError(error)
        }
    }

    private func pollTranscript(id: String, apiKey: String) async throws -> String {
        let pollURL = transcriptEndpoint.appendingPathComponent(id)
        var attempts = 0

        while attempts < 120 {
            attempts += 1

            let request = apiClient.buildRequest(
                url: pollURL,
                method: "GET",
                headers: ["authorization": apiKey]
            )

            do {
                let (data, statusCode) = try await apiClient.execute(request)

                switch statusCode {
                case 200:
                    let response = try JSONDecoder().decode(AssemblyAIPollResponse.self, from: data)
                    switch response.status {
                    case "completed":
                        return response.text ?? ""
                    case "error":
                        throw TranscriptionError.serverError(statusCode: 422, message: response.error ?? "Transcription failed")
                    default:
                        try await Task.sleep(nanoseconds: 750_000_000)
                    }
                case 401:
                    throw TranscriptionError.invalidAPIKey
                case 403:
                    throw TranscriptionError.accessDenied
                case 429:
                    throw TranscriptionError.rateLimited(retryAfter: nil)
                case 500...599:
                    let message = apiClient.extractErrorMessage(from: data) ?? "Internal server error"
                    throw TranscriptionError.serverError(statusCode: statusCode, message: message)
                default:
                    let message = apiClient.extractErrorMessage(from: data) ?? "Unexpected polling error"
                    throw TranscriptionError.serverError(statusCode: statusCode, message: message)
                }
            } catch let error as APIClientError {
                throw mapClientError(error)
            } catch let error as DecodingError {
                throw TranscriptionError.decodingError(error)
            }
        }

        throw TranscriptionError.timeout
    }
}
