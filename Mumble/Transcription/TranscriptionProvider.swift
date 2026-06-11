import Foundation

// MARK: - Transcription Model Option

struct TranscriptionModelOption: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let detail: String?
    let requestModelIDs: [String]

    var primaryRequestModelID: String {
        requestModelIDs.first ?? id
    }
}

// MARK: - Transcription Provider

enum TranscriptionProvider: String, CaseIterable, Codable, Identifiable {
    case groq
    case fireworks
    case elevenLabs
    case deepgram
    case assemblyAI

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .fireworks: return "Fireworks AI"
        case .elevenLabs: return "ElevenLabs"
        case .deepgram: return "Deepgram"
        case .assemblyAI: return "AssemblyAI"
        }
    }

    var shortDescription: String {
        switch self {
        case .groq:
            return "Fast Whisper-compatible transcription."
        case .fireworks:
            return "OpenAI-compatible Whisper transcription."
        case .elevenLabs:
            return "Scribe-powered speech recognition."
        case .deepgram:
            return "General-purpose speech-to-text with smart formatting."
        case .assemblyAI:
            return "High-accuracy batch transcription."
        }
    }

    var keySetupURL: URL {
        switch self {
        case .groq:
            return URL(string: "https://console.groq.com/keys")!
        case .fireworks:
            return URL(string: "https://app.fireworks.ai/api-keys")!
        case .elevenLabs:
            return URL(string: "https://elevenlabs.io/app/settings/api-keys")!
        case .deepgram:
            return URL(string: "https://console.deepgram.com/project/api-keys")!
        case .assemblyAI:
            return URL(string: "https://www.assemblyai.com/dashboard")!
        }
    }

    var keySetupLabel: String {
        switch self {
        case .groq:
            return "Get an API key at console.groq.com"
        case .fireworks:
            return "Get an API key at app.fireworks.ai"
        case .elevenLabs:
            return "Get an API key in ElevenLabs settings"
        case .deepgram:
            return "Get an API key at console.deepgram.com"
        case .assemblyAI:
            return "Get an API key in the AssemblyAI dashboard"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .groq:
            return "gsk_..."
        case .fireworks:
            return "Paste your Fireworks API key"
        case .elevenLabs:
            return "Paste your ElevenLabs API key"
        case .deepgram:
            return "Paste your Deepgram API key"
        case .assemblyAI:
            return "Paste your AssemblyAI API key"
        }
    }

    var suggestedKeyPrefix: String? {
        switch self {
        case .groq:
            return "gsk_"
        default:
            return nil
        }
    }

    var minimumKeyLength: Int {
        switch self {
        case .groq:
            return 20
        case .fireworks, .elevenLabs, .deepgram, .assemblyAI:
            return 16
        }
    }

    var models: [TranscriptionModelOption] {
        switch self {
        case .groq:
            return [
                TranscriptionModelOption(
                    id: "whisper-large-v3",
                    displayName: "Whisper Large v3",
                    detail: "Highest accuracy multilingual Groq model.",
                    requestModelIDs: ["whisper-large-v3"]
                ),
                TranscriptionModelOption(
                    id: "whisper-large-v3-turbo",
                    displayName: "Whisper Large v3 Turbo",
                    detail: "Faster multilingual Groq model.",
                    requestModelIDs: ["whisper-large-v3-turbo"]
                )
            ]
        case .fireworks:
            return [
                TranscriptionModelOption(
                    id: "whisper-v3-turbo",
                    displayName: "Whisper v3 Turbo",
                    detail: "Recommended fast Fireworks model.",
                    requestModelIDs: ["whisper-v3-turbo"]
                ),
                TranscriptionModelOption(
                    id: "whisper-v3",
                    displayName: "Whisper v3",
                    detail: "Higher-cost Fireworks base Whisper v3 model.",
                    requestModelIDs: ["whisper-v3"]
                )
            ]
        case .elevenLabs:
            return [
                TranscriptionModelOption(
                    id: "scribe_v2",
                    displayName: "Scribe v2",
                    detail: "Current ElevenLabs batch transcription model.",
                    requestModelIDs: ["scribe_v2"]
                )
            ]
        case .deepgram:
            return [
                TranscriptionModelOption(
                    id: "nova-3",
                    displayName: "Nova-3",
                    detail: "Latest recommended general Deepgram model.",
                    requestModelIDs: ["nova-3"]
                ),
                TranscriptionModelOption(
                    id: "nova-2",
                    displayName: "Nova-2",
                    detail: "Previous-generation general Deepgram model.",
                    requestModelIDs: ["nova-2"]
                ),
                TranscriptionModelOption(
                    id: "base",
                    displayName: "Base",
                    detail: "Lowest-cost general Deepgram model.",
                    requestModelIDs: ["base"]
                )
            ]
        case .assemblyAI:
            return [
                TranscriptionModelOption(
                    id: "universal-3-pro-fallback",
                    displayName: "Universal-3 Pro + Fallback",
                    detail: "Recommended: tries Universal-3 Pro first, then Universal-2.",
                    requestModelIDs: ["universal-3-pro", "universal-2"]
                ),
                TranscriptionModelOption(
                    id: "universal-3-pro",
                    displayName: "Universal-3 Pro",
                    detail: "Highest-accuracy AssemblyAI model.",
                    requestModelIDs: ["universal-3-pro"]
                ),
                TranscriptionModelOption(
                    id: "universal-2",
                    displayName: "Universal-2",
                    detail: "Broader language coverage fallback model.",
                    requestModelIDs: ["universal-2"]
                )
            ]
        }
    }

    var defaultModelID: String {
        switch self {
        case .groq:
            return "whisper-large-v3"
        case .fireworks:
            return "whisper-v3-turbo"
        case .elevenLabs:
            return "scribe_v2"
        case .deepgram:
            return "nova-3"
        case .assemblyAI:
            return "universal-3-pro-fallback"
        }
    }

    func modelOption(id: String?) -> TranscriptionModelOption {
        models.first(where: { $0.id == id }) ?? models.first(where: { $0.id == defaultModelID }) ?? models[0]
    }

    func keychainAccount(baseAccount: String) -> String {
        switch self {
        case .groq:
            return baseAccount
        case .fireworks, .elevenLabs, .deepgram, .assemblyAI:
            return "\(baseAccount).\(rawValue)"
        }
    }
}

// MARK: - Transcription Provider Config

struct TranscriptionProviderConfig: Codable, Equatable {
    var selectedProvider: TranscriptionProvider
    var selectedModelIDs: [String: String]

    static let `default` = TranscriptionProviderConfig(
        selectedProvider: .groq,
        selectedModelIDs: [:]
    )

    private static let userDefaultsKey = "com.mumble.transcriptionProviderConfig"

    static func load() -> TranscriptionProviderConfig {
        guard
            let data = UserDefaults.standard.data(forKey: userDefaultsKey),
            let config = try? JSONDecoder().decode(TranscriptionProviderConfig.self, from: data)
        else {
            return .default
        }
        return config
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
    }

    func selectedModel(for provider: TranscriptionProvider) -> TranscriptionModelOption {
        provider.modelOption(id: selectedModelIDs[provider.rawValue])
    }

    mutating func selectModel(_ modelID: String, for provider: TranscriptionProvider) {
        selectedModelIDs[provider.rawValue] = modelID
    }
}

// MARK: - Transcription Service Protocol

protocol AudioTranscriptionService {
    var provider: TranscriptionProvider { get }

    @discardableResult
    func validateAPIKey(_ key: String, model: TranscriptionModelOption?) async throws -> Bool

    func transcribe(
        audioData: Data,
        apiKey: String,
        model: TranscriptionModelOption,
        prompt: String?
    ) async throws -> String
}

extension AudioTranscriptionService {
    func transcribeWithRetry(
        audioData: Data,
        apiKey: String,
        model: TranscriptionModelOption,
        prompt: String? = nil,
        maxRetries: Int = 2
    ) async throws -> String {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                return try await transcribe(
                    audioData: audioData,
                    apiKey: apiKey,
                    model: model,
                    prompt: prompt
                )
            } catch let error as TranscriptionError {
                lastError = error

                switch error {
                case .noAPIKey, .invalidAPIKey, .invalidAudioData, .rateLimited, .decodingError, .timeout, .accessDenied:
                    throw error
                case .serverError(let statusCode, _) where statusCode < 500:
                    throw error
                case .serverError, .networkError:
                    break
                }

                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                throw TranscriptionError.networkError(error)
            }
        }

        throw lastError ?? TranscriptionError.networkError(
            NSError(
                domain: "TranscriptionService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "All retry attempts exhausted"]
            )
        )
    }
}

// MARK: - Transcription Service Factory

enum TranscriptionServiceFactory {
    static func service(for provider: TranscriptionProvider) -> any AudioTranscriptionService {
        switch provider {
        case .groq:
            return GroqTranscriptionService.shared
        case .fireworks:
            return FireworksTranscriptionService.shared
        case .elevenLabs:
            return ElevenLabsTranscriptionService.shared
        case .deepgram:
            return DeepgramTranscriptionService.shared
        case .assemblyAI:
            return AssemblyAITranscriptionService.shared
        }
    }
}
