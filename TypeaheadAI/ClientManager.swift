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

enum HTTPStatusCode: Int {
    case ok = 200
    case clientError = 400
}

enum ClientManagerError: Error {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
}

class ClientManager {
    private let session: URLSession

    private let apiUrl = URL(string: "https://typeahead-ai.fly.dev/get_response")!
    private let semaphore = DispatchSemaphore(value: 5) // max 5 concurrent requests
    private static let defaultRetryCount = 3
    private static let defaultInitialDelay: TimeInterval = 1.0
    private static let defaultTimeoutInSecs: TimeInterval = 10

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Dictionary to hold a queue for each request based on request ID
    private var requestQueues: [UUID: DispatchQueue] = [:]

    init(session: URLSession = .shared) {
        self.session = session
    }

    // Retrieves or creates a DispatchQueue based on the provided identifier.
    private func getQueue(for identifier: UUID) -> DispatchQueue {
        if let queue = requestQueues[identifier] {
            return queue
        } else {
            let newQueue = DispatchQueue(
                label: "ai.typeahead.TypeaheadAI.\(identifier.uuidString)",
                qos: .background
            )
            requestQueues[identifier] = newQueue
            return newQueue
        }
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
    ///   - retryCount: The number of times to retry the request. Default is 3.
    ///   - delay: The initial time interval to wait before retrying. Default is 1 second.
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
        retryCount: Int = defaultRetryCount,
        delay: TimeInterval = defaultInitialDelay,
        timeout: TimeInterval = defaultTimeoutInSecs,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // NOTE: nested function for convenient recursion
        func underlyingRequest(retryCount: Int, delay: TimeInterval) {
            // Obtain the queue designated for this request based on its UUID.
            let queue = getQueue(for: id)

            // Dispatch the request logic to the designated queue.
            queue.async {
                let payload = RequestPayload(
                    username: username,
                    userFullName: userFullName,
                    userObjective: userObjective,
                    copiedText: copiedText,
                    url: url,
                    activeAppName: activeAppName,
                    activeAppBundleIdentifier: activeAppBundleIdentifier
                )

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
                    // Check for network errors.
                    if let error = error {
                        handleError(error, retryCount: retryCount, delay: delay)
                        return
                    }

                    // Process the server's response.
                    if let data = data {
                        do {
                            self.semaphore.signal()
                            let decodedResponse = try JSONDecoder().decode(ResponsePayload.self, from: data)
                            if let statusCode = HTTPStatusCode(rawValue: decodedResponse.responseCode) {
                                switch statusCode {
                                case .ok:
                                    completion(.success(decodedResponse.textToPaste))
                                case .clientError:
                                    completion(.failure(ClientManagerError.clientError(decodedResponse.errorMessage ?? "")))
                                }
                            } else {
                                completion(.failure(ClientManagerError.serverError(decodedResponse.errorMessage ?? "")))
                            }
                        } catch {
                            // An error occurred while decoding the response, invoke the completion handler with failure.
                            self.logger.debug("Failed to process response: \(error.localizedDescription)")
                            completion(.failure(error))
                        }
                    }
                }

                // Start the URLSession data task.
                task.resume()
            }
        }

        // NOTE: nested error and retry handler
        func handleError(_ error: Error, retryCount: Int, delay: TimeInterval) {
            if retryCount > 0 {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self.logger.debug("Retrying... Remaining attempts: \(retryCount)")
                    underlyingRequest(retryCount: retryCount - 1, delay: delay * 2)
                }
            } else {
                semaphore.signal()
                self.logger.debug("Max retry attempts reached. Error: \(error.localizedDescription)")
                completion(.failure(ClientManagerError.retriesExceeded("Max retry attempts reached")))
            }
        }

        // Use an async function to handle the request
        async {
            if semaphore.wait(wallTimeout: .distantFuture) == .success {
                defer { semaphore.signal() }  // Ensure semaphore is signaled even if we exit early

                underlyingRequest(retryCount: 3, delay: 1)
            } else {
                // Max concurrency reached
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Max Concurrency Reached"
                    alert.informativeText = "Please wait before trying again."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }
    }
}
