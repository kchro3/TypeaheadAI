//
//  Functions.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/16/23.
//

import AppKit
import Foundation

enum FunctionError: LocalizedError {
    case openURL(_ message: String)
    case notFound(_ message: String)

    var errorDescription: String {
        switch self {
        case .openURL(let message): return message
        case .notFound(let message): return message
        }
    }
}

struct FunctionCall: Codable {
    let name: String
    let args: [String: String]
}

class Functions {
    static func openURL(_ url: String) async throws {
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)
    }

    static func parseAndCallFunction(jsonString: String, modalManager: ModalManager) async throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            return
        }

        switch functionCall.name {
        case "open_url":
            try await openURL(functionCall.args["url"]!)
            await modalManager.appendText("Opening \(functionCall.args["url"] ?? "url")...")
        default:
            throw FunctionError.notFound("Function \(functionCall.name) not found.")
        }
    }
}
