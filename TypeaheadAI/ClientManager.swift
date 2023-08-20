//
//  ClientManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import Foundation

struct RequestPayload: Codable {
    let prompt: String
    let url: String
}

struct ResponsePayload: Codable {
    let response: String
}

func sendRequest(prompt: String, url: String, completion: @escaping (Result<String, Error>) -> Void) {
    // Set the API endpoint
    let apiUrl = URL(string: "http://127.0.0.1:5000/get_response")!

    // Create the payload
    let payload = RequestPayload(prompt: prompt, url: url)

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
                completion(.success(decodedResponse.response))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // Start the task
    task.resume()
}
