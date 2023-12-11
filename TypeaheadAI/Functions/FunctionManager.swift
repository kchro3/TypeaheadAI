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

struct FunctionCall: Codable, Equatable {
    let id: String?
    let name: String
    let args: [String: String]
}

struct Action: Codable {
    let id: String
    let action: String
    let textToPaste: String?
}

class FunctionManager: CanFetchAppContext, CanSimulateSelectAll, CanSimulateCopy, CanSimulatePaste, CanSimulateClose {
    func openURL(_ url: String) async throws {
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)
    }

    func parseAndCallFunction(jsonString: String, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            await modalManager.setError("Failed to parse function", appContext: appContext)
            return
        }

        switch functionCall.name {
        case "perform_ui_action":

            guard let serializedActions = functionCall.args["actions"],
                  let jsonData = serializedActions.data(using: .utf8),
                  let actions = try? JSONDecoder().decode([Action].self, from: jsonData),
                  let elementMap = appInfo?.elementMap else {
                await modalManager.setError("Failed to perform UI action", appContext: appContext)
                return
            }

            await modalManager.appendFunction(
                "Performing actions: \(actions)...",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )

            if let bundleIdentifier = appContext?.bundleIdentifier,
               let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                // Activate the app, bringing it to the foreground
                app.activate(options: [.activateIgnoringOtherApps])
            }

            await modalManager.closeModal()

            for action in actions {
                try await Task.sleep(for: .seconds(1))

                if let axElement = elementMap[action.id] {
                    let result = AXUIElementPerformAction(axElement, action.action as CFString)

                    if result == .success, let textToPaste = action.textToPaste {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(textToPaste, forType: .string)
                        try await Task.sleep(for: .seconds(1))

                        try await simulatePaste()
                    } else if result == .success {
                    } else {
                        // TERMINATE on failure
                        await modalManager.showModal()

                        if result == .actionUnsupported {
                            await modalManager.appendToolError("No such action \(action)", functionCall: functionCall, appContext: appContext)
                        } else {
                            await modalManager.appendToolError("Action could not be performed", functionCall: functionCall, appContext: appContext)
                        }

                        return
                    }
                } else {
                    // TERMINATE on invalid action
                    await modalManager.showModal()
                    await modalManager.appendToolError("No such element \(action.id)", functionCall: functionCall, appContext: appContext)
                    return
                }
            }

            await modalManager.appendTool(
                "Performed actions successfully.",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )

            await modalManager.showModal()

        case "open_url":

            guard let url = functionCall.args["url"], let prompt = functionCall.args["prompt"] else {
                await modalManager.setError("Failed to open url...", appContext: appContext)
                return
            }

            // Deal with <noop> case
            guard prompt != "<noop>" else {
                guard url != "<current>" else {
                    await modalManager.appendToolError("Should not call <noop> on <current>", functionCall: functionCall, appContext: appContext)
                    try await modalManager.continueReplying()
                    return
                }

                await modalManager.appendFunction(
                    "Opening \(url) ...",
                    functionCall: functionCall,
                    appContext: appInfo?.appContext
                )

                try await openURL(url)
                await modalManager.appendTool(
                    "Opened \(url) successfully",
                    functionCall: functionCall,
                    appContext: appContext)

                try await modalManager.continueReplying()
                return
            }

            if url == "<current>" {
                await modalManager.appendFunction(
                    "Scraping current page...",
                    functionCall: functionCall,
                    appContext: appInfo?.appContext
                )

                if let bundleIdentifier = appContext?.bundleIdentifier,
                   let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
                    // Activate the app, bringing it to the foreground
                    app.activate(options: [.activateIgnoringOtherApps])
                }

                await modalManager.closeModal()
                try await Task.sleep(for: .seconds(1))
                try await simulateSelectAll()
                try await simulateCopy()
            } else {
                await modalManager.appendFunction(
                    "Opening \(functionCall.args["url"] ?? "url"). Will wait for 5 secs to load the page...",
                    functionCall: functionCall,
                    appContext: appContext
                )

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
            }

            await modalManager.showModal()

            if let htmlString = NSPasteboard.general.string(forType: .html),
               let sanitizedHTML = try? htmlString.sanitizeHTML() {

                let markdownString = sanitizedHTML.renderXMLToMarkdown(.init(throwUnkownElement: .ignore))
                
                if url == "<current>" {
                    await modalManager.appendTool(
                        "Here's what I copied from the current page:\n\(markdownString)\n\nMy next goal: \(prompt)",
                        functionCall: functionCall,
                        appContext: appContext)
                } else {
                    await modalManager.appendTool(
                        "Here's what I copied from \(url):\n\(markdownString)\n\nMy next goal: \(prompt)",
                        functionCall: functionCall,
                        appContext: appContext)
                }

            } else if let copiedText = NSPasteboard.general.string(forType: .string) {
                if url == "<current>" {
                    await modalManager.appendTool(
                        "Here's what I copied from the current page:\n\(copiedText)\n\nMy next goal: \(prompt)",
                        functionCall: functionCall,
                        appContext: appContext)
                } else {
                    await modalManager.appendTool(
                        "Here's what I copied from \(url):\n\(copiedText)\n\nMy next goal: \(prompt)",
                        functionCall: functionCall,
                        appContext: appContext)
                }
            }

            try await modalManager.continueReplying()
        default:
            throw FunctionError.notFound("Function \(functionCall.name) not found.")
        }
    }
}
