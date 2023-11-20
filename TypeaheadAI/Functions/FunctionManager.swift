//
//  FunctionManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/16/23.
//

import AppKit
import Foundation
import WebKit

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

class FunctionManager: CanSimulateCopy, CanSimulateSelectAll {
    func openURL(_ url: String) async throws {
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)
    }

    func parseAndCallFunction(jsonString: String, modalManager: ModalManager) async throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            return
        }

        switch functionCall.name {
        case "open_url":
            print(functionCall.args)
            let url = functionCall.args["url"]!
            await modalManager.closeModal()
            try await openURL(url)
            try await Task.sleep(for: .seconds(3))
            try await simulateSelectAll()
            try await simulateCopy()
            await modalManager.showModal()

            guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                await modalManager.appendText("Couldn't fetch data from \(url)")
                return
            }

            try await modalManager.clientManager?.predict(
                id: UUID(),
                copiedText: copiedText,
                incognitoMode: !modalManager.online,
                userObjective: functionCall.args["prompt"],
                stream: true,
                streamHandler: modalManager.defaultHandler,
                completion: modalManager.defaultCompletionHandler
            )
        default:
            throw FunctionError.notFound("Function \(functionCall.name) not found.")
        }
    }
}
