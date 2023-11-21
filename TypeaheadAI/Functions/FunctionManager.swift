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
    func openURL(_ url: String, prompt: String, modalManager: ModalManager) async throws {
        // Fetch the original app context
        let appContext = try await fetchAppContext()

        // Add URL to message
        await modalManager.appendText("Opening [\(url)](\(url))...")

        // Open URL
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)

        // Close window temporarily
        await modalManager.closeModal()

        // Let the page load for 5 seconds
        try await Task.sleep(for: .seconds(5))

        // Simulate selecting -> copying -> closing the window
        try await simulateSelectAll()
        try await simulateCopy()
        try await simulateClose()

        // Return to the original app
        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
        }

        // Show the window
        await modalManager.showModal()

        // HIDDEN messages under the hood
        if let copiedText = NSPasteboard.general.string(forType: .string) {
            await modalManager.setText("Here's what I copied from \(url):\n\(copiedText)", isHidden: true)
        }
        await modalManager.setUserMessage(prompt, isHidden: true)

        // Reply
        await modalManager.replyToUserMessage(refresh: false)
    }

    func openApp(_ appName: String, _ bundleIdentifier: String, prompt: String, modalManager: ModalManager) async throws {
        // Fetch the original app context
        let appContext = try await fetchAppContext()

        // Add URL to message
        await modalManager.appendText("Opening \(appName)...")
    }

    func parseAndCallFunction(jsonString: String, modalManager: ModalManager) async throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            return
        }

        switch functionCall.name {
        case "open_url":
            // Check arguments
            guard let url = functionCall.args["url"], let prompt = functionCall.args["prompt"] else {
                await modalManager.setError("Failed to open url...")
                return
            }

            try await openURL(url, prompt: prompt, modalManager: modalManager)
        case "open_app":
            // Check arguments
            guard let app = functionCall.args["app"], 
                  let bundleIdentifier = functionCall.args["bundleIdentifier"],
                  let prompt = functionCall.args["prompt"] else {

                await modalManager.setError("Failed to open app...")
                return
            }
            
            try await openApp(app, bundleIdentifier, prompt: prompt, modalManager: modalManager)
        default:
            throw FunctionError.notFound("Function \(functionCall.name) not found.")
        }
    }
}
