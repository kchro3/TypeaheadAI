//
//  ClientManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import AppKit
import CoreData
import Foundation
import os.log

struct RequestPayload: Codable {
    var token: String?
    var username: String
    var userFullName: String
    var userObjective: String?
    var userBio: String
    var userLang: String
    var copiedText: String
    var messages: [Message]?
    var history: [Message]?
    var url: String
    var activeAppName: String
    var activeAppBundleIdentifier: String
    var vision: Bool
}

struct OnboardingRequestPayload: Codable {
    var username: String
    var userFullName: String
    var userBio: String
    var userLang: String
    var onboardingStep: Int
    var version: String
}

struct ImageRequestPayload: Codable {
    let prompt: String
}

struct ErrorResponse: Codable {
    let detail: String
}

/// Copied from https://github.com/MarcoDotIO/OpenAIKit/blob/main/Sources/OpenAIKit/Types/Enums/Images/ImageData.swift
public enum ImageData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case url
        case b64Json = "b64_json"
    }

    /// The image is stored as a URL string.
    case url(String)

    /// The image is stored as a Base64 binary.
    case b64Json(String)

    /// The image itself.
    public var image: String {
        switch self {
        case let .b64Json(b64Json): return b64Json
        case let .url(url): return url
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        do {
            let urlAssociate = try container.decode(String.self, forKey: .url)
            self = .url(urlAssociate)
        } catch {
            let b64Associate = try container.decode(String.self, forKey: .b64Json)
            self = .b64Json(b64Associate)
        }
    }
}

/// Copied from https://github.com/MarcoDotIO/OpenAIKit/blob/main/Sources/OpenAIKit/Types/Structs/Schemas/Images/ImageResponse.swift
public struct ImageResponse: Codable {
    /// The creation date of the response.
    public let created: Int

    /// The data sent within the response containing either `URL` or `Base64` data.
    public let data: [ImageData]
}

struct ResponsePayload: Codable {
    let textToPaste: String
    let assumedIntent: String
    let choices: [String]
}

enum Mode: String, Codable {
    case text
    case image
}

struct ChunkPayload: Codable {
    var text: String?
    var mode: Mode?
    let finishReason: String?
}

enum ClientManagerError: Error {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
    case appError(_ message: String)
    case networkError(_ message: String)
    case corruptedDataError(_ message: String)

    var localizedDescription: String {
        switch self {
        case .badRequest(let message): message
        case .retriesExceeded(let message): message
        case .clientError(let message): message
        case .serverError(let message): message
        case .appError(let message): message
        case .networkError(let message): message
        case .corruptedDataError(let message): message
        }
    }
}

struct SuggestIntentsPayload: Codable {
    let intents: [String]
}

class ClientManager {
    var llamaModelManager: LlamaModelManager? = nil
    var promptManager: PromptManager? = nil
    var appContextManager: AppContextManager? = nil
    var intentManager: IntentManager? = nil

    private let session: URLSession

    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/v2/get_stream")!
    private let apiOnboarding = URL(string: "https://typeahead-ai.fly.dev/onboarding")!
    private let apiImage = URL(string: "https://typeahead-ai.fly.dev/v2/get_image")!
    private let apiIntents = URL(string: "https://typeahead-ai.fly.dev/v2/suggest_intents")!

//    private let apiUrlStreaming = URL(string: "http://localhost:8080/v2/get_stream")!
//    private let apiOnboarding = URL(string: "http://localhost:8080/onboarding")!
//    private let apiImage = URL(string: "http://localhost:8080/v2/get_image")!
//    private let apiIntents = URL(string: "http://localhost:8080/v2/suggest_intents")!

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Add a Task property to manage the streaming task
    private var currentStreamingTask: Task<Void, Error>? = nil
    private var currentOnboardingTask: Task<Void, Error>? = nil
    private var cached: (String, String?)? = nil

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getActivePrompt() -> String? {
        return self.promptManager?.getActivePrompt()
    }

    func suggestIntents(
        id: UUID,
        token: String,
        username: String,
        userFullName: String,
        userObjective: String?,
        userBio: String,
        userLang: String,
        copiedText: String,
        messages: [Message],
        history: [Message]?,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool,
        timeout: TimeInterval = 30
    ) async throws -> SuggestIntentsPayload? {
        let payload = RequestPayload(
            token: token,
            username: username,
            userFullName: userFullName,
            userObjective: userObjective,
            userBio: userBio,
            userLang: userLang,
            copiedText: copiedText,
            messages: self.sanitizeMessages(messages),
            history: history,
            url: url,
            activeAppName: activeAppName,
            activeAppBundleIdentifier: activeAppBundleIdentifier,
            vision: true
        )

        // NOTE: Cache the payload so we know what text was copied
        self.cacheResponse(nil, for: payload)

        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Something went wrong...")
        }

        var urlRequest = URLRequest(url: self.apiIntents, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await self.session.data(for: urlRequest)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ClientManagerError.serverError("Something went wrong...")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ClientManagerError.serverError(errorResponse.detail)
            } else {
                throw ClientManagerError.serverError("Something went wrong...")
            }
        }

        return try JSONDecoder().decode(SuggestIntentsPayload.self, from: data)
    }

    /// Easier to use this wrapper function.
    func predict(
        id: UUID,
        copiedText: String,
        incognitoMode: Bool,
        history: [Message]? = nil,
        userObjective: String? = nil,
        timeout: TimeInterval = 30,
        stream: Bool = false,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) {
        self.logger.info("incognito: \(incognitoMode)")
        // If objective is not specified in the request, fall back on the active prompt.
        let objective = userObjective ?? self.promptManager?.getActivePrompt()

        guard let appCtxManager = appContextManager else {
            self.logger.error("Something is wrong with the initialization")
            completion(.failure(ClientManagerError.appError("Something went wrong.")))
            return
        }

        appCtxManager.getActiveAppInfo { (appName, bundleIdentifier, url) in
            Task {
                await self.sendStreamRequest(
                    id: id,
                    token: UserDefaults.standard.string(forKey: "token") ?? "",
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: objective,
                    userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                    userLang: Locale.preferredLanguages.first ?? "",
                    copiedText: copiedText,
                    messages: [],
                    history: history,
                    url: url?.host ?? "",
                    activeAppName: appName ?? "unknown",
                    activeAppBundleIdentifier: bundleIdentifier ?? "",
                    incognitoMode: incognitoMode,
                    streamHandler: streamHandler,
                    completion: completion
                )
            }
        }
    }

    /// Refine the currently cached request
    func refine(
        messages: [Message],
        incognitoMode: Bool,
        userIntent: String? = nil,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) {
        self.logger.info("incognito: \(incognitoMode)")
        if let (key, _) = cached,
           let data = key.data(using: .utf8),
           let payload = try? JSONDecoder().decode(RequestPayload.self, from: data) {
            appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in

                Task {
                    var history: [Message]? = nil
                    if let userIntent = userIntent {
                        // NOTE: We cached the copiedText earlier
                        _ = self.intentManager?.addIntentEntry(
                            prompt: userIntent,
                            copiedText: payload.copiedText,
                            activeUrl: payload.url,
                            activeAppName: payload.activeAppName,
                            activeAppBundleIdentifier: payload.activeAppBundleIdentifier
                        )

                        history = self.intentManager?.fetchIntents(
                            limit: 10,
                            url: payload.url,
                            appName: payload.activeAppName,
                            bundleIdentifier: payload.activeAppBundleIdentifier
                        )
                    }

                    await self.sendStreamRequest(
                        id: UUID(),
                        token: UserDefaults.standard.string(forKey: "token") ?? "",
                        username: payload.username,
                        userFullName: payload.userFullName,
                        userObjective: payload.userObjective,
                        userBio: payload.userBio,
                        userLang: payload.userLang,
                        copiedText: payload.copiedText,
                        messages: self.sanitizeMessages(messages),
                        history: history,
                        url: payload.url,
                        activeAppName: payload.activeAppName,
                        activeAppBundleIdentifier: payload.activeAppBundleIdentifier,
                        incognitoMode: incognitoMode,
                        streamHandler: streamHandler,
                        completion: completion
                    )
                }
            }
        } else {
            logger.error("No cached request to refine")
            appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
                Task {
                    await self.sendStreamRequest(
                        id: UUID(),
                        token: UserDefaults.standard.string(forKey: "token") ?? "",
                        username: NSUserName(),
                        userFullName: NSFullUserName(),
                        userObjective: "",
                        userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                        userLang: Locale.preferredLanguages.first ?? "",
                        copiedText: "",
                        messages: self.sanitizeMessages(messages),
                        history: nil,
                        url: url?.host ?? "unknown",
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: incognitoMode,
                        streamHandler: streamHandler,
                        completion: completion
                    )
                }
            }
        }
    }

    /// Onboarding flow
    func onboarding(
        onboardingStep: Int,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) {
        Task {
            await self.sendOnboardingRequest(
                id: UUID(),
                username: NSUserName(),
                userFullName: NSFullUserName(),
                userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                userLang: Locale.preferredLanguages.first ?? "",
                incognitoMode: false,
                onboardingStep: onboardingStep,
                streamHandler: streamHandler,
                completion: completion
            )
        }
    }

    /// Sends a request to the server with the given parameters and listens for a stream of data.
    ///
    /// - Parameters:
    ///   - Same as sendRequest
    ///   - streamHandler: A closure to be executed for each chunk of data received.
    private func sendOnboardingRequest(
        id: UUID,
        username: String,
        userFullName: String,
        userBio: String,
        userLang: String,
        incognitoMode: Bool,
        onboardingStep: Int,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) async {
        currentOnboardingTask?.cancel()
        currentOnboardingTask = Task.detached { [weak self] in
            let payload = OnboardingRequestPayload(
                username: username,
                userFullName: userFullName,
                userBio: userBio,
                userLang: userLang,
                onboardingStep: onboardingStep,
                version: "onboarding_v3"
            )

            do {
                let stream = try self?.performOnboardingTask(
                    payload: payload,
                    timeout: timeout,
                    completion: completion
                )

                guard let stream = stream else {
                    self?.logger.debug("Failed to get stream")
                    return
                }

                for try await text in stream {
                    self?.logger.debug("stream: \(text)")
                    streamHandler(.success(text))
                }
            } catch {
                streamHandler(.failure(error))
            }
        }
    }

    /// Sends a request to the server with the given parameters and listens for a stream of data.
    ///
    /// - Parameters:
    ///   - Same as sendRequest
    ///   - streamHandler: A closure to be executed for each chunk of data received.
    func sendStreamRequest(
        id: UUID,
        token: String?,
        username: String,
        userFullName: String,
        userObjective: String?,
        userBio: String,
        userLang: String,
        copiedText: String,
        messages: [Message],
        history: [Message]?,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool,
        onboardingMode: Bool = false,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) async {
        cancelStreamingTask()
        currentStreamingTask = Task.detached { [weak self] in
            let payload = RequestPayload(
                token: token,
                username: username,
                userFullName: userFullName,
                userObjective: userObjective,
                userBio: userBio,
                userLang: userLang,
                copiedText: copiedText,
                messages: self?.sanitizeMessages(messages),
                history: history,
                url: url,
                activeAppName: activeAppName,
                activeAppBundleIdentifier: activeAppBundleIdentifier,
                vision: true
            )

            if let output = self?.getCachedResponse(for: payload) {
                streamHandler(.success(output))
                return
            }

            if incognitoMode {
                if let result: Result<ChunkPayload, Error> = await self?.performStreamOfflineTask(
                    payload: payload, timeout: timeout, streamHandler: streamHandler) {

                    completion(result)

                    // Cache successful requests
                    switch result {
                    case .success(let output):
                        self?.cacheResponse(output.text, for: payload)
                        break
                    case .failure(_):
                        self?.cacheResponse(nil, for: payload)
                        break
                    }
                } else {
                    completion(.failure(ClientManagerError.appError("Something went wrong...")))
                }
            } else {
                do {
                    let stream = try self?.performStreamOnlineTask(
                        payload: payload,
                        timeout: timeout,
                        completion: { result in
                            completion(result)

                            // Cache successful response
                            switch result {
                            case .success(let output):
                                self?.cacheResponse(output.text, for: payload)
                            case .failure(let error):
                                self?.logger.error("\(error.localizedDescription)")
                            }
                        }
                    )

                    guard let stream = stream else {
                        self?.logger.debug("Failed to get stream")
                        return
                    }

                    for try await text in stream {
                        self?.logger.debug("stream: \(text)")
                        streamHandler(.success(text))
                    }
                } catch {
                    self?.cacheResponse(nil, for: payload)
                    streamHandler(.failure(error))
                }
            }
        }
    }

    func generateImage(payload: ImageRequestPayload, timeout: TimeInterval = 10.0) async throws -> ImageData? {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Something went wrong...")
        }

        var urlRequest = URLRequest(url: self.apiImage, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await self.session.data(for: urlRequest)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ClientManagerError.serverError("Something went wrong...")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ClientManagerError.serverError(errorResponse.detail)
            } else {
                throw ClientManagerError.serverError("Something went wrong...")
            }
        }

        let response = try JSONDecoder().decode(ImageResponse.self, from: data)
        return response.data[0]
    }

    private func performStreamOnlineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) throws -> AsyncThrowingStream<String, Error> {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Encoding error")
        }
        
        return AsyncThrowingStream { continuation in
            Task {
                var urlRequest = URLRequest(url: self.apiUrlStreaming, timeoutInterval: timeout)
                urlRequest.httpMethod = "POST"
                urlRequest.httpBody = httpBody
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let (data, resp) = try await URLSession.shared.bytes(for: urlRequest)

                guard let httpResponse = resp as? HTTPURLResponse else {
                    continuation.finish(throwing: ClientManagerError.serverError("Something went wrong..."))
                    return
                }

                guard 200...299 ~= httpResponse.statusCode else {
                    continuation.finish(throwing: ClientManagerError.serverError("Something went wrong..."))
                    return
                }

                // NOTE: This is complicated, but we want to support a case where the AI is responding to a user request
                // but also making a function call. To support this, if a payload is something other than .text,
                // it is a special payload and should be cached separately.
                // In the future, we can think about how to support completions with a full response, but worry about that later.
                var bufferedPayload: ChunkPayload = ChunkPayload(finishReason: nil)
                for try await line in data.lines {
                    if let data = line.data(using: .utf8),
                       let response = try? JSONDecoder().decode(ChunkPayload.self, from: data),
                       let text = response.text {

                        switch response.mode ?? .text {
                        case .text:
                            continuation.yield(text)
                            if bufferedPayload.mode != .image {
                                bufferedPayload.text = (bufferedPayload.text ?? "") + text
                                bufferedPayload.mode = .text
                            }
                        case .image:
                            bufferedPayload = response
                        }
                    }
                }
                
                completion(.success(bufferedPayload))
                continuation.finish()
            }
        }
    }

    private func performOnboardingTask(
        payload: OnboardingRequestPayload,
        timeout: TimeInterval,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) throws -> AsyncThrowingStream<String, Error> {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Encoding error")
        }

        return AsyncThrowingStream { continuation in
            Task {
                var urlRequest = URLRequest(url: self.apiOnboarding, timeoutInterval: timeout)
                urlRequest.httpMethod = "POST"
                urlRequest.httpBody = httpBody
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

                let (data, resp) = try await URLSession.shared.bytes(for: urlRequest)

                guard let httpResponse = resp as? HTTPURLResponse else {
                    continuation.finish(throwing: ClientManagerError.serverError("Something went wrong..."))
                    return
                }

                guard 200...299 ~= httpResponse.statusCode else {
                    continuation.finish(throwing: ClientManagerError.serverError("Something went wrong..."))
                    return
                }

                // NOTE: This is complicated, but we want to support a case where the AI is responding to a user request
                // but also making a function call. To support this, if a payload is something other than .text,
                // it is a special payload and should be cached separately.
                // In the future, we can think about how to support completions with a full response, but worry about that later.
                var bufferedPayload: ChunkPayload = ChunkPayload(finishReason: nil)
                for try await line in data.lines {
                    if let data = line.data(using: .utf8),
                       let response = try? JSONDecoder().decode(ChunkPayload.self, from: data),
                       let text = response.text {

                        switch response.mode ?? .text {
                        case .text:
                            continuation.yield(text)
                            if bufferedPayload.mode != .image {
                                bufferedPayload.text = (bufferedPayload.text ?? "") + text
                                bufferedPayload.mode = .text
                            }
                        case .image:
                            bufferedPayload = response
                        }
                    }
                }

                completion(.success(bufferedPayload))
                continuation.finish()
            }
        }
    }

    private func performStreamOfflineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) async -> Result<ChunkPayload, Error> {
        guard let modelManager = self.llamaModelManager else {
            return .failure(ClientManagerError.appError("Model Manager not found"))
        }

        return modelManager.predict(payload: payload, streamHandler: streamHandler)
    }

    func cancelStreamingTask() {
        currentStreamingTask?.cancel()
    }

    private func generateCacheKey(from payload: RequestPayload) -> String? {
        let encoder = JSONEncoder()

        do {
            var payloadCopy = payload
            payloadCopy.url = ""
            payloadCopy.activeAppName = ""
            payloadCopy.activeAppBundleIdentifier = ""

            let jsonData = try encoder.encode(payloadCopy)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            self.logger.error("Encoding failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func getCachedResponse(for requestPayload: RequestPayload) -> String? {
        guard let cacheKey = generateCacheKey(from: requestPayload) else {
            return nil
        }

        if let (key, val) = cached {
            return (key == cacheKey) ? val : nil
        } else {
            return nil
        }
    }

    private func cacheResponse(_ response: String?, for requestPayload: RequestPayload) {
        if let cacheKey = generateCacheKey(from: requestPayload) {
            self.logger.debug("Overwrite cached request")
            cached = (cacheKey, response)
        }
    }

    private func sanitizeMessages(_ messages: [Message]) -> [Message] {
        return messages.map { originalMessage in
            var messageCopy = originalMessage
            messageCopy.attributed = nil
            if case .image(_) = messageCopy.messageType {
                messageCopy.messageType = .string
            }
            return messageCopy
        }
    }

    func flushCache() {
        cached = nil
    }
}
