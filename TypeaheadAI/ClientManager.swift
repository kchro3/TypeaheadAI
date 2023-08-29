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

enum TypeaheadAIError: Error {
    case runtimeError(message: String)
}

class ClientManager {

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    func sendRequest(
        username: String,
        userFullName: String,
        userObjective: String,
        copiedText: String,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        retryCount: Int = 3,
        delay: TimeInterval = 1,
        timeout: TimeInterval = 10,
        completion: @escaping (Result<String, Error>) -> Void
    ) {

        let apiUrl = URL(string: "https://typeahead-ai.fly.dev/get_response")!

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
            completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Encoding error"])))
            return
        }

        var request = URLRequest(url: apiUrl, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = httpBody
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                if retryCount > 0 {
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        self.logger.debug("Retrying... Remaining attempts: \(retryCount)")
                        self.sendRequest(
                            username: username,
                            userFullName: userFullName,
                            userObjective: userObjective,
                            copiedText: copiedText,
                            url: url,
                            activeAppName: activeAppName,
                            activeAppBundleIdentifier: activeAppBundleIdentifier,
                            retryCount: retryCount - 1,
                            delay: delay * 2,
                            completion: completion
                        )
                    }
                } else {
                    self.logger.debug("Max retry attempts reached. Error: \(error.localizedDescription)")
                    completion(.failure(error))
                }
                return
            }

            if let data = data {
                do {
                    let decodedResponse = try JSONDecoder().decode(ResponsePayload.self, from: data)
                    if decodedResponse.responseCode == 200 {
                        self.logger.debug("OK")
                        completion(.success(decodedResponse.textToPaste))
                    } else {
                        self.logger.debug("\(decodedResponse.responseCode): \(decodedResponse.errorMessage ?? "no error message")")
                        completion(.failure(TypeaheadAIError.runtimeError(message: decodedResponse.errorMessage ?? "")))
                    }
                } catch {
                    self.logger.debug("Failed to process response: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            }
        }

        task.resume()
    }
}
