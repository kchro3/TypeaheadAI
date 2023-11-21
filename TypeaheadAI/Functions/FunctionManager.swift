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

class FunctionManager: CanFetchAppContext, CanSimulateSelectAll, CanSimulateCopy, CanSimulateClose {
    func openURL(_ url: String) async throws {
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)
    }

    func parseAndCallFunction(jsonString: String, modalManager: ModalManager) async throws {
        let appContext = try await fetchAppContext()

        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            return
        }

        switch functionCall.name {
        case "open_url":
            
            guard let url = functionCall.args["url"], let prompt = functionCall.args["prompt"] else {
                await modalManager.setError("Failed to open url...")
                return
            }

            await modalManager.appendText("Opening \(functionCall.args["url"] ?? "url")...")
            try await openURL(functionCall.args["url"]!)
            await modalManager.closeModal()
            try await Task.sleep(for: .seconds(5))
            try await simulateSelectAll()
            try await simulateCopy()
            try await simulateClose()

            if let bundleIdentifier = appContext?.bundleIdentifier,
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                    // Activate the app, bringing it to the foreground
                    app.activate(options: [.activateIgnoringOtherApps])
            }

            await modalManager.showModal()

            if let copiedText = NSPasteboard.general.string(forType: .string) {
                await modalManager.setText("Here's what I copied from \(url):\n\(copiedText)", isHidden: true)
            }

            await modalManager.setUserMessage(prompt, isHidden: true)
            await modalManager.replyToUserMessage(refresh: false)
        default:
            throw FunctionError.notFound("Function \(functionCall.name) not found.")
        }
    }
}
