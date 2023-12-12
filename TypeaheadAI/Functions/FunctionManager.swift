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

class FunctionManager: CanFetchAppContext, CanGetUIElements, CanSimulateSelectAll, CanSimulateCopy, CanSimulatePaste, CanSimulateClose {
    func openURL(_ url: String) async throws {
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)
    }

    func parseAndCallFunction(jsonString: String, appInfo: AppInfo?, modalManager: ModalManager) async {
        let appContext = appInfo?.appContext
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            await modalManager.setError("Failed to parse function", appContext: appContext)
            return
        }

        switch functionCall.name {
        case "open_application":
            do {
                try await openApplication(functionCall, appInfo: appInfo, modalManager: modalManager)
            } catch {
                await modalManager.setError("Failed when opening application...", appContext: appContext)
            }

        case "open_url":
            do {
                try await openURL(functionCall, appInfo: appInfo, modalManager: modalManager)
            } catch {
                await modalManager.setError("Failed when opening url...", appContext: appContext)
            }

        case "perform_ui_action":
            do {
                try await performUIAction(functionCall, appInfo: appInfo, modalManager: modalManager)
            } catch {
                await modalManager.setError("Failed when interacting with UI...", appContext: appContext)
            }

        case "open_and_scrape_url":
            do {
                try await openAndScrapeURL(functionCall, appInfo: appInfo, modalManager: modalManager)
            } catch {
                await modalManager.setError("Failed when scraping URL...", appContext: appContext)
            }

        default:
            await modalManager.setError("Function \(functionCall.name) not supported", appContext: appContext)
        }
    }
}
