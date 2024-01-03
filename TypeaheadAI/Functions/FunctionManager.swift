//
//  Functions.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/16/23.
//

import AppKit
import Foundation

enum FunctionName: String, Codable {
    case openApplication = "open_application"
    case openFile = "open_file"
    case openURL = "open_url"
    case performUIAction = "perform_ui_action"
    case saveFile = "save_file"
}

enum FunctionArgs: Codable {
    case openApplication(bundleIdentifier: String)
    case openFile(file: String)
    case openURL(url: String)
    case performUIAction(action: Action)
    case saveFile(id: String, file: String)

    var humanReadable: String {
        switch self {
        case .openApplication(let bundleIdentifier):
            return "Opening \(bundleIdentifier)..."
        case .openFile(let file):
            return "Opening \(file)..."
        case .openURL(let url):
            return "Opening \(url) and waiting for 5 seconds for the page to load..."
        case .performUIAction(let action):
            return action.narration
        case .saveFile(_, let file):
            return "Saving \(file)..."
        }
    }
}

struct FunctionCall: Codable, Equatable {
    let id: String?
    let name: FunctionName
    var args: [String: JSONAny]

    func parseArgs() throws -> FunctionArgs {
        switch self.name {
        case .openApplication:
            guard let bundleIdentifier = self.stringArg("bundleIdentifier") else {
                throw ClientManagerError.functionArgParsingError("Failed to open application...")
            }

            return .openApplication(bundleIdentifier: bundleIdentifier)

        case .openFile:
            guard let file = self.stringArg("file") else {
                throw ClientManagerError.functionArgParsingError("Failed to open file...")
            }

            return .openFile(file: file)

        case .openURL:
            guard let url = self.stringArg("url") else {
                throw ClientManagerError.functionArgParsingError("Failed to open file...")
            }

            return .openURL(url: url)

        case .performUIAction:
            guard let id = self.stringArg("id"),
                  let delayInMillis = self.intArg("delayInMillis"),
                  let narration = self.stringArg("narration") else {
                throw ClientManagerError.functionArgParsingError("Failed to perform UI action...")
            }

            return .performUIAction(action: Action(
                id: id,
                narration: narration,
                inputText: self.stringArg("inputText"),
                pressEnter: self.boolArg("pressEnter"),
                delayInMillis: delayInMillis
            ))

        case .saveFile:
            guard let id = self.stringArg("id"),
                  let file = self.stringArg("file") else {
                throw ClientManagerError.functionArgParsingError("Failed to save file...")
            }

            return .saveFile(id: id, file: file)
        }
    }
}

class FunctionManager: CanFetchAppContext,
                       CanSimulateSelectAll,
                       CanSimulateCopy,
                       CanSimulatePaste,
                       CanSimulateClose,
                       CanSimulateGoToFile,
                       CanFocusOnElement {

    /// Return the parsed FunctionCall
    func parse(jsonString: String) async throws -> FunctionCall {
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            throw ClientManagerError.functionParsingError("Function could not be parsed: \(jsonString)")
        }

        return functionCall
    }

    func call(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws -> AppInfo {
        switch functionCall.name {
        case .openApplication:
            try await self.openApplication(functionCall, appInfo: appInfo)
        case .openFile:
            try await self.openFile(functionCall, appInfo: appInfo)
        case .openURL:
            try await self.openURL(functionCall, appInfo: appInfo)
        case .performUIAction:
            try await self.performUIAction(functionCall, appInfo: appInfo)
        case .saveFile:
            try await self.saveFile(functionCall, appInfo: appInfo)
        }

        // Return updated app state
        var newAppContext = try await fetchAppContext()
        let (newUIElement, newElementMap) = getUIElements(appContext: newAppContext)
        try Task.checkCancellation()

        guard let serializedUIElement = newUIElement?.serialize() else {
            throw ClientManagerError.functionCallError(
                "Failed to serialize UI state",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }
        
        try Task.checkCancellation()
        newAppContext?.serializedUIElement = serializedUIElement

        return AppInfo(
            appContext: newAppContext,
            elementMap: newElementMap,
            apps: appInfo?.apps ?? [:]
        )
    }
}

extension FunctionCall {
    func stringArg(_ arg: String) -> String? {
        guard let value = args[arg] else { return nil }

        switch value {
        case .string(let stringValue):
            return stringValue
        default: return nil
        }
    }

    func stringArrayArg(_ arg: String) -> [String]? {
        guard let value = args[arg] else { return nil }

        switch value {
        case .array(let arrayValue):
            return arrayValue.compactMap { element in
                if case .string(let stringValue) = element {
                    return stringValue
                } else {
                    return nil
                }
            }
        default: return nil
        }
    }

    func doubleArg(_ arg: String) -> Double? {
        guard let value = args[arg] else { return nil }

        switch value {
        case .double(let doubleValue):
            return doubleValue
        default: return nil
        }
    }

    func intArg(_ arg: String) -> Int? {
        guard let value = args[arg] else { return nil }

        switch value {
        case .integer(let intValue):
            return intValue
        default: return nil
        }
    }

    func boolArg(_ arg: String) -> Bool? {
        guard let value = args[arg] else { return nil }

        switch value {
        case .boolean(let boolValue):
            return boolValue
        default: return nil
        }
    }
}
