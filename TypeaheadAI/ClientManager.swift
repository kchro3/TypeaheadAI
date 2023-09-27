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
    var onboarding: Bool = false
}

struct OnboardingRequestPayload: Codable {
    var username: String
    var userFullName: String
    var userBio: String
    var userLang: String
    var onboardingStep: Int
    var version: String
}

struct ResponsePayload: Codable {
    let textToPaste: String
    let assumedIntent: String
    let choices: [String]
}

struct ChunkPayload: Codable {
    let text: String?
    let finishReason: String?
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
}

struct StreamMessage: Decodable {
    let role: String?
    let content: String?
}

enum ClientManagerError: Error {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
    case appError(_ message: String)
    case networkError(_ message: String)
}

class ClientManager {
    var llamaModelManager: LlamaModelManager? = nil
    var promptManager: PromptManager? = nil
    var appContextManager: AppContextManager? = nil

    private let session: URLSession

//    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/v2/get_stream")!
    private let apiOnboarding = URL(string: "https://typeahead-ai.fly.dev/onboarding")!
    private let apiUrlStreaming = URL(string: "http://localhost:8080/v3/get_stream")!
//    private let apiOnboarding = URL(string: "http://localhost:8080/onboarding")!

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Add a Task property to manage the streaming task
    private var currentStreamingTask: Task<Void, Error>? = nil
    private var currentOnboardingTask: Task<Void, Error>? = nil
    private var cached: (String, String?)? = nil

    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getActivePrompt() -> String? {
        return self.promptManager?.getActivePrompt()
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
        completion: @escaping (Result<String, Error>) -> Void
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
                    url: url ?? "",
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
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) {
        self.logger.info("incognito: \(incognitoMode)")
        if let (key, _) = cached,
           let data = key.data(using: .utf8),
           let payload = try? JSONDecoder().decode(RequestPayload.self, from: data) {
            appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
                Task {
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
                        history: nil,
                        url: payload.url,
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: incognitoMode,
                        streamHandler: streamHandler,
                        completion: { _ in }
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
                        url: url ?? "unknown",
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: incognitoMode,
                        streamHandler: streamHandler,
                        completion: { _ in }
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
        completion: @escaping (Result<String, Error>) -> Void
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
        completion: @escaping (Result<String, Error>) -> Void
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

            if let result: Result<String, Error> = await self?.performOnboardingTask(payload: payload, timeout: timeout, streamHandler: streamHandler) {
                completion(result)
            } else {
                completion(.failure(ClientManagerError.appError("Something went wrong...")))
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
        completion: @escaping (Result<String, Error>) -> Void
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
                onboarding: onboardingMode
            )

            if let output = self?.getCachedResponse(for: payload) {
                streamHandler(.success(output))
                return
            }

            if incognitoMode {
                if let result: Result<String, Error> = await self?.performStreamOfflineTask(payload: payload, timeout: timeout, streamHandler: streamHandler) {

                    completion(result)

                    // Cache successful requests
                    switch result {
                    case .success(let output):
                        self?.cacheResponse(output, for: payload)
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
                    let stream = try await self?.performStreamOnlineTask(
                        payload: payload,
                        timeout: timeout,
                        completion: { result in
                            completion(result)

                            // Cache successful response
                            switch result {
                            case .success(let output):
                                self?.cacheResponse(output, for: payload)
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

    private func performStreamOnlineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        completion: @escaping (Result<String, Error>) -> Void
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Encoding error")
        }

        var urlRequest = URLRequest(url: self.apiUrlStreaming, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (result, response) = try await URLSession.shared.bytes(for: urlRequest)
        try Task.checkCancellation()

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientManagerError.serverError("Server error")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            throw ClientManagerError.serverError("Server error")
        }

        var responseText = ""
        return AsyncThrowingStream {
            for try await line in result.lines {
                print(line)
                try Task.checkCancellation()
                if line.hasPrefix("data: "),
                   let data = line.dropFirst(6).data(using: .utf8),
                   let response = try? self.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                   let text = response.choices.first?.delta.content {
                    responseText += text
                    return text
                }
            }

            print(responseText)
            return nil
        }
    }

    private func performOnboardingTask(
        payload: OnboardingRequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) async -> Result<String, Error> {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            let error: Result<String, Error> = .failure(ClientManagerError.badRequest("Encoding error"))
            streamHandler(error)
            return error
        }

        var request = URLRequest(url: self.apiOnboarding, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        var output = ""
        do {
            let (stream, _) = try await URLSession.shared.bytes(for: request)

            for try await line in stream.lines {
                let decodedResponse = try JSONDecoder().decode(ChunkPayload.self, from: line.data(using: .utf8)!)
                if let text = decodedResponse.text {
                    output += text
                    streamHandler(.success(text))
                }
            }
        } catch {
            let err: Result<String, Error> = .failure(error)
            streamHandler(err)
            return err
        }

        return .success(output)
    }

    private func performStreamOfflineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) async -> Result<String, Error> {
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
            cached = (cacheKey, response)
        }
    }

    private func sanitizeMessages(_ messages: [Message]) -> [Message] {
        return messages.map { originalMessage in
            var messageCopy = originalMessage
            messageCopy.attributed = nil
            return messageCopy
        }
    }

    func flushCache() {
        cached = nil
    }
}
