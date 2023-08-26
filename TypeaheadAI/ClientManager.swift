//
//  ClientManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import Foundation

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

func sendRequest(
    username: String,
    userFullName: String,
    userObjective: String,
    copiedText: String,
    url: String,
    activeAppName: String,
    activeAppBundleIdentifier: String,
    completion: @escaping (Result<String, Error>) -> Void) {
    // Set the API endpoint
    let apiUrl = URL(string: "https://typeahead-ai.fly.dev/get_response")!

    // Create the payload
    let payload = RequestPayload(
        username: username,
        userFullName: userFullName,
        userObjective: userObjective,
        copiedText: copiedText,
        url: url,
        activeAppName: activeAppName,
        activeAppBundleIdentifier: activeAppBundleIdentifier
    )
    print(payload)

    // Encode the payload
    guard let httpBody = try? JSONEncoder().encode(payload) else {
        completion(.failure(NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Encoding error"])))
        return
    }

    // Create a URLRequest object
    var request = URLRequest(url: apiUrl)
    request.httpMethod = "POST"
    request.httpBody = httpBody
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    // Create a URLSession task
    let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
        if let error = error {
            completion(.failure(error))
            return
        }

        if let data = data {
            do {
                // Decode the response
                let decodedResponse = try JSONDecoder().decode(ResponsePayload.self, from: data)
                print(decodedResponse)
                if decodedResponse.responseCode == 200 {
                    completion(.success(decodedResponse.textToPaste))
                } else {
                    print("\(decodedResponse.responseCode): " + (decodedResponse.errorMessage ?? "no error message"))
                    completion(.failure(TypeaheadAIError.runtimeError(message: decodedResponse.errorMessage ?? "")))
                }
            } catch {
                print("failed to process response")
                completion(.failure(error))
            }
        }
    }

    // Start the task
    task.resume()
}
