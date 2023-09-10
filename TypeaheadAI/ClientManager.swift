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
    let username: String
    let userFullName: String
    let userObjective: String
    let userBio: String
    let userLang: String
    let copiedText: String
    let url: String
    let activeAppName: String
    let activeAppBundleIdentifier: String
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
}

class ClientManager {
    var llamaModelManager: LlamaModelManager? = nil
    var promptManager: PromptManager? = nil
    private let scriptManager = ScriptManager()

    private let session: URLSession

    private let apiUrl = URL(string: "https://typeahead-ai.fly.dev/get_response")!
    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/get_response_stream")!

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Add a Task property to manage the streaming task
    private var currentStreamingTask: Task<Void, Error>? = nil

    init(session: URLSession = .shared) {
        self.session = session
    }

    deinit {
        Task {
            self.scriptManager.stopAccessingDirectory()
        }
    }

    /// Easier to use this wrapper function.
    func predict(
        id: UUID,
        copiedText: String,
        incognitoMode: Bool,
        timeout: TimeInterval = 10,
        stream: Bool = false,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        getActiveApplicationInfo { (appName, bundleIdentifier, url) in
            if stream {
                Task {
                    await self.sendStreamRequest(
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
                        streamHandler: completion
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
                        completion: completion)
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
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool,
        timeout: TimeInterval = 10,
        streamHandler: @escaping (Result<String, Error>) -> Void
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
                url: url,
                activeAppName: activeAppName,
                activeAppBundleIdentifier: activeAppBundleIdentifier
            )

            if (incognitoMode) {
                await self?.performStreamOfflineTask(
                    payload: payload,
                    timeout: timeout,
                    streamHandler: streamHandler
                )
            } else {
                await self?.performStreamOnlineTask(
                    payload: payload,
                    timeout: timeout,
                    streamHandler: streamHandler
                )
            }
        }
    }

    private func performStreamOnlineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) async {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            streamHandler(.failure(ClientManagerError.badRequest("Encoding error")))
            return
        }

        var request = URLRequest(url: self.apiUrlStreaming, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (stream, _) = try await URLSession.shared.bytes(for: request)

            for try await line in stream.lines {
                let decodedResponse = try JSONDecoder().decode(ChunkPayload.self, from: line.data(using: .utf8)!)
                if let text = decodedResponse.text {
                    streamHandler(.success(text))
                }
            }
        } catch {
            streamHandler(.failure(error))
        }
    }

    private func performStreamOfflineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) async {
        do {
            try self.llamaModelManager?.predict(
                payload: payload,
                streamHandler: streamHandler
            )
        } catch {
            streamHandler(.failure(error))
        }
    }

    func cancelStreamingTask() {
        currentStreamingTask?.cancel()
    }

    private func getActiveApplicationInfo(completion: @escaping (String?, String?, String?) -> Void) {
        self.logger.debug("get active app")
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let appName = activeApp.localizedName
            self.logger.debug("Detected active app: \(appName ?? "none")")
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                self.scriptManager.executeScript { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to execute script: \(error.errorDescription ?? "Unknown error")")
                        completion(appName, bundleIdentifier, nil)
                    } else if let url = result?.stringValue {
                        self.logger.info("Successfully executed script. URL: \(url)")
                        completion(appName, bundleIdentifier, url)
                    }
                }
            } else {
                completion(appName, bundleIdentifier, nil)
            }
        } else {
            completion(nil, nil, nil)
        }
    }
}
