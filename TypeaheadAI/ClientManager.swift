//
//  ClientManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import AppKit
import Foundation
import os.log

struct RequestPayload: Codable {
    var username: String
    var userFullName: String
    var userObjective: String
    var userBio: String
    var userLang: String
    var copiedText: String
    var messages: [Message]?
    var url: String
    var activeAppName: String
    var activeAppBundleIdentifier: String
    var onboarding: Bool = false
}

struct ResponsePayload: Codable {
    let textToPaste: String
    let responseCode: Int
    let errorMessage: String?
}

struct ChunkPayload: Codable {
    let text: String?
    let finishReason: String?
}

enum ClientManagerError: Error {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
    case appError(_ message: String)
}

class ClientManager {
    var llamaModelManager: LlamaModelManager? = nil
    var promptManager: PromptManager? = nil
    var appContextManager: AppContextManager? = nil

    private let session: URLSession

    private let apiUrl = URL(string: "https://typeahead-ai.fly.dev/get_response")!
    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/get_response_stream")!
//    private let apiUrlStreaming = URL(string: "http://localhost:8080/get_response_stream")!

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Add a Task property to manage the streaming task
    private var currentStreamingTask: Task<Void, Error>? = nil
    private var cached: (String, String?)? = nil

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
        userObjective: String? = nil,
        timeout: TimeInterval = 10,
        stream: Bool = false,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // If objective is not specified in the request, fall back on the active prompt.
        let objective = userObjective ?? self.promptManager?.getActivePrompt() ?? (stream ? "respond to this in <20 words" : "respond to this")

        appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
            if stream {
                Task {
                    await self.sendStreamRequest(
                        id: id,
                        username: NSUserName(),
                        userFullName: NSFullUserName(),
                        userObjective: objective,
                        userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                        userLang: Locale.preferredLanguages.first ?? "",
                        copiedText: copiedText,
                        messages: [],
                        url: url ?? "",
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: incognitoMode,
                        streamHandler: streamHandler,
                        completion: completion
                    )
                }
            } else {
                DispatchQueue.main.async {
                    self.sendRequest(
                        id: id,
                        username: NSUserName(),
                        userFullName: NSFullUserName(),
                        userObjective: self.promptManager?.getActivePrompt() ?? "",
                        userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                        userLang: Locale.preferredLanguages.first ?? "",
                        copiedText: copiedText,
                        url: url ?? "",
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: incognitoMode,
                        completion: completion
                    )
                }
            }
        }
    }

    /// Refine the currently cached request
    func refine(
        messages: [Message],
        incognitoMode: Bool,
        timeout: TimeInterval = 10,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) {
        if let (key, _) = cached,
           let data = key.data(using: .utf8),
           let payload = try? JSONDecoder().decode(RequestPayload.self, from: data) {
            appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
                Task {
                    await self.sendStreamRequest(
                        id: UUID(),
                        username: payload.username,
                        userFullName: payload.userFullName,
                        userObjective: payload.userObjective,
                        userBio: payload.userBio,
                        userLang: payload.userLang,
                        copiedText: payload.copiedText,
                        messages: self.sanitizeMessages(messages),
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
                        username: NSUserName(),
                        userFullName: NSFullUserName(),
                        userObjective: "",
                        userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                        userLang: Locale.preferredLanguages.first ?? "",
                        copiedText: "",
                        messages: self.sanitizeMessages(messages),
                        url: url ?? "unknown",
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: false,
                        streamHandler: streamHandler,
                        completion: { _ in }
                    )
                }
            }
        }
    }

    /// Onboarding flow
    func onboarding(
        messages: [Message],
        timeout: TimeInterval = 10,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) {
        if messages.isEmpty {
            appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
                Task {
                    await self.sendStreamRequest(
                        id: UUID(),
                        username: NSUserName(),
                        userFullName: NSFullUserName(),
                        userObjective: "",
                        userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                        userLang: Locale.preferredLanguages.first ?? "",
                        copiedText: "",
                        messages: self.sanitizeMessages(messages),
                        url: url ?? "unknown",
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: false,
                        onboardingMode: true,
                        streamHandler: streamHandler,
                        completion: { _ in }
                    )
                }
            }
        } else {
            // Continue the conversation
            guard let (key, _) = cached,
                  let data = key.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(RequestPayload.self, from: data) else {
                logger.error("No cached request to refine")
                return
            }

            appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
                Task {
                    await self.sendStreamRequest(
                        id: UUID(),
                        username: payload.username,
                        userFullName: payload.userFullName,
                        userObjective: payload.userObjective,
                        userBio: payload.userBio,
                        userLang: payload.userLang,
                        copiedText: payload.copiedText,
                        messages: self.sanitizeMessages(messages),
                        url: payload.url,
                        activeAppName: appName ?? "unknown",
                        activeAppBundleIdentifier: bundleIdentifier ?? "",
                        incognitoMode: false,
                        onboardingMode: true,
                        streamHandler: streamHandler,
                        completion: { _ in }
                    )
                }
            }
        }
    }

    /// Sends a request to the server with the given parameters.
    ///
    /// - Parameters:
    ///   - identifier: A UUID to uniquely identify this request.
    ///   - username: The username of the user.
    ///   - userFullName: The full name of the user.
    ///   - userObjective: The objective of the user.
    ///   - userBio: Details about the user.
    ///   - userLang: User's preferred language.
    ///   - copiedText: The text that the user has copied.
    ///   - url: The URL that the user is currently viewing.
    ///   - activeAppName: The name of the app that is currently active.
    ///   - activeAppBundleIdentifier: The bundle identifier of the currently active app.
    ///   - incognitoMode: Whether or not the request is sent to an online or offline model.
    ///   - timeout: The timeout for the request. Default is 10 seconds.
    ///   - completion: A closure to be executed once the request is complete.
    private func sendRequest(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
        userBio: String,
        userLang: String,
        copiedText: String,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool,
        timeout: TimeInterval = 10,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let payload = RequestPayload(
            username: username,
            userFullName: userFullName,
            userObjective: userObjective,
            userBio: userBio,
            userLang: userLang,
            copiedText: copiedText,
            url: url,
            activeAppName: activeAppName,
            activeAppBundleIdentifier: activeAppBundleIdentifier
        )

        if (incognitoMode) {
            completion(.success("[work in progress...]"))
            return
        }

        // Encode the RequestPayload instance into JSON data.
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            completion(.failure(ClientManagerError.badRequest("Encoding error")))
            return
        }

        // Create an HTTP POST request with the API URL and encoded payload.
        var request = URLRequest(url: self.apiUrl, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Initialize a URLSession data task with the request.
        let task = self.session.dataTask(with: request) { (data, response, error) in
            // Process the server's response.
            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(ResponsePayload.self, from: data)

                    switch decodedResponse.responseCode {
                    case 200:
                        self.logger.debug("OK")
                        completion(.success(decodedResponse.textToPaste))
                    case 400:
                        self.logger.debug("Client error")
                        completion(.failure(ClientManagerError.clientError(decodedResponse.errorMessage ?? "")))
                    default:
                        self.logger.debug("Server error")
                        completion(.failure(ClientManagerError.serverError(decodedResponse.errorMessage ?? "")))
                    }
                } catch {
                    // An error occurred while decoding the response, invoke the completion handler with failure.
                    self.logger.debug("Failed to process response: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                completion(.failure(ClientManagerError.serverError("unknown error")))
            }
        }

        // Start the URLSession data task.
        task.resume()
    }

    /// Sends a request to the server with the given parameters and listens for a stream of data.
    ///
    /// - Parameters:
    ///   - Same as sendRequest
    ///   - streamHandler: A closure to be executed for each chunk of data received.
    private func sendStreamRequest(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
        userBio: String,
        userLang: String,
        copiedText: String,
        messages: [Message],
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool,
        onboardingMode: Bool = false,
        timeout: TimeInterval = 10,
        streamHandler: @escaping (Result<String, Error>) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) async {
        cancelStreamingTask()
        currentStreamingTask = Task.detached { [weak self] in
            let payload = RequestPayload(
                username: username,
                userFullName: userFullName,
                userObjective: userObjective,
                userBio: userBio,
                userLang: userLang,
                copiedText: copiedText,
                messages: self?.sanitizeMessages(messages),
                url: url,
                activeAppName: activeAppName,
                activeAppBundleIdentifier: activeAppBundleIdentifier,
                onboarding: onboardingMode
            )

            if let output = self?.getCachedResponse(for: payload) {
                streamHandler(.success(output))
                return
            }

            if let result: Result<String, Error> = (incognitoMode)
                    ? await self?.performStreamOfflineTask(payload: payload, timeout: timeout, streamHandler: streamHandler)
                    : await self?.performStreamOnlineTask(payload: payload, timeout: timeout, streamHandler: streamHandler) {

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
            }
        }
    }

    private func performStreamOnlineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) async -> Result<String, Error> {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            let error: Result<String, Error> = .failure(ClientManagerError.badRequest("Encoding error"))
            streamHandler(error)
            return error
        }

        var request = URLRequest(url: self.apiUrlStreaming, timeoutInterval: timeout)
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
                    self.cacheResponse(output, for: payload)
                    streamHandler(.success(text))
                }
            }
        } catch {
            let err: Result<String, Error> = .failure(error)
            self.cacheResponse(nil, for: payload)
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
