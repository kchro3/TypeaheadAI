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

enum ClientManagerError: Error {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
}

class ClientManager {
    private let session: URLSession

    private let apiUrl = URL(string: "https://typeahead-ai.fly.dev/get_response")!

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

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
}
