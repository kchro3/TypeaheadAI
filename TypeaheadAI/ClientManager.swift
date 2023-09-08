//
//  ClientManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import Foundation
import os.log

struct RequestPayload: Codable {
    let username: String
    let userFullName: String
    let userObjective: String
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

    /// Sends a request to the server with the given parameters.
    ///
    /// - Parameters:
    ///   - identifier: A UUID to uniquely identify this request.
    ///   - username: The username of the user.
    ///   - userFullName: The full name of the user.
    ///   - userObjective: The objective of the user.
    ///   - copiedText: The text that the user has copied.
    ///   - url: The URL that the user is currently viewing.
    ///   - activeAppName: The name of the app that is currently active.
    ///   - activeAppBundleIdentifier: The bundle identifier of the currently active app.
    ///   - incognitoMode: Whether or not the request is sent to an online or offline model.
    ///   - timeout: The timeout for the request. Default is 10 seconds.
    ///   - completion: A closure to be executed once the request is complete.
    func sendRequest(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
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
    func sendStreamRequest(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
        copiedText: String,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool,
        timeout: TimeInterval = 10,
        streamHandler: @escaping (String?, Error?) -> Void
    ) async {
        cancelStreamingTask()
        currentStreamingTask = Task.detached { [weak self] in
            do {
                if (incognitoMode) {
                    try await self?.performStreamOfflineTask(
                        id: id,
                        username: username,
                        userFullName: userFullName,
                        userObjective: userObjective,
                        copiedText: copiedText,
                        url: url,
                        activeAppName: activeAppName,
                        activeAppBundleIdentifier: activeAppBundleIdentifier,
                        timeout: timeout,
                        streamHandler: streamHandler
                    )
                } else {
                    try await self?.performStreamOnlineTask(
                        id: id,
                        username: username,
                        userFullName: userFullName,
                        userObjective: userObjective,
                        copiedText: copiedText,
                        url: url,
                        activeAppName: activeAppName,
                        activeAppBundleIdentifier: activeAppBundleIdentifier,
                        timeout: timeout,
                        streamHandler: streamHandler
                    )
                }
            } catch {
                // Handle any errors that 'performStreamTask' might throw
                streamHandler(nil, error)
            }
        }
    }

    private func performStreamOnlineTask(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
        copiedText: String,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        timeout: TimeInterval,
        streamHandler: @escaping (String?, Error?) -> Void
    ) async throws {
        let payload = RequestPayload(
            username: username,
            userFullName: userFullName,
            userObjective: userObjective,
            copiedText: copiedText,
            url: url,
            activeAppName: activeAppName,
            activeAppBundleIdentifier: activeAppBundleIdentifier
        )

        guard let httpBody = try? JSONEncoder().encode(payload) else {
            streamHandler(nil, ClientManagerError.badRequest("Encoding error"))
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
                    streamHandler(text, nil)
                }
            }
        } catch {
            streamHandler(nil, error)
        }
    }

    private func performStreamOfflineTask(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
        copiedText: String,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        timeout: TimeInterval,
        streamHandler: @escaping (String?, Error?) -> Void
    ) async throws {
        let payload = RequestPayload(
            username: username,
            userFullName: userFullName,
            userObjective: userObjective,
            copiedText: copiedText,
            url: url,
            activeAppName: activeAppName,
            activeAppBundleIdentifier: activeAppBundleIdentifier
        )

        do {
            try self.llamaModelManager?.predict(
                payload: payload,
                streamHandler: streamHandler
            )
        } catch {
            streamHandler(nil, error)
        }
    }

    func cancelStreamingTask() {
        currentStreamingTask?.cancel()
    }
}
