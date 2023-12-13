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

// Custom type to handle various JSON value types
enum JSONAny: Codable, Equatable {
    case string(String)
    case double(Double)
    case integer(Int)
    case boolean(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .integer(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .double(doubleVal)
        } else if let stringVal = try? container.decode(String.self) {
            self = .string(stringVal)
        } else if let boolVal = try? container.decode(Bool.self) {
            self = .boolean(boolVal)
        } else {
            throw DecodingError.typeMismatch(JSONAny.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Value is not JSON compatible"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let str):
            try container.encode(str)
        case .double(let num):
            try container.encode(num)
        case .integer(let int):
            try container.encode(int)
        case .boolean(let bool):
            try container.encode(bool)
        }
    }
}

struct FunctionCall: Codable, Equatable {
    let id: String?
    let name: String
    let args: [String: JSONAny]

    func stringArg(_ arg: String) -> String? {
        guard let value = args[arg] else { return nil }

        switch value {
        case .string(let stringValue):
            return stringValue
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

class FunctionManager: ObservableObject, CanFetchAppContext, CanGetUIElements, CanSimulateSelectAll, CanSimulateCopy, CanSimulatePaste, CanSimulateClose {

    @Published var isExecuting: Bool = false
    private var currentTask: Task<Void, Error>? = nil

    init() {
        startMonitoring()
    }

    private func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.cancelTaskWrapper(_:)),
            name: .chatCanceled,
            object: nil
        )
    }

    func openURL(_ url: String) async throws {
        guard let url = URL(string: url) else {
            throw FunctionError.openURL("URL not found")
        }

        NSWorkspace.shared.open(url)
    }

    @MainActor
    func parseAndCallFunction(jsonString: String, appInfo: AppInfo?, modalManager: ModalManager) async {
        currentTask?.cancel()
        currentTask = nil
        isExecuting = false

        let appContext = appInfo?.appContext
        guard let jsonData = jsonString.data(using: .utf8),
              let functionCall = try? JSONDecoder().decode(FunctionCall.self, from: jsonData) else {
            modalManager.setError("Failed to parse function", appContext: appContext)
            return
        }

        isExecuting = true
        currentTask = Task.init { [weak self] in
            switch functionCall.name {
            case "open_application":
                do {
                    try await self?.openApplication(functionCall, appInfo: appInfo, modalManager: modalManager)
                } catch {
                    modalManager.setError("Failed when opening application...", appContext: appContext)
                }

            case "open_url":
                do {
                    try await self?.openURL(functionCall, appInfo: appInfo, modalManager: modalManager)
                } catch {
                    modalManager.setError("Failed when opening url...", appContext: appContext)
                }

            case "perform_ui_action":
                do {
                    try await self?.performUIAction(functionCall, appInfo: appInfo, modalManager: modalManager)
                } catch {
                    modalManager.setError("Failed when interacting with UI...", appContext: appContext)
                }

            case "open_and_scrape_url":
                do {
                    try await self?.openAndScrapeURL(functionCall, appInfo: appInfo, modalManager: modalManager)
                } catch {
                    modalManager.setError("Failed when scraping URL...", appContext: appContext)
                }

            default:
                modalManager.setError("Function \(functionCall.name) not supported", appContext: appContext)
            }

            DispatchQueue.main.async {
                self?.currentTask = nil
                self?.isExecuting = false
            }
        }
    }

    @objc func cancelTaskWrapper(_ notification: NSNotification) {
        guard let modalManager = notification.userInfo?["modalManager"] as? ModalManager else { return }

        self.currentTask?.cancel()
        self.currentTask = nil
        self.isExecuting = false

        var toolCallId: String? = nil
        var fnCall: FunctionCall? = nil
        var appContext: AppContext? = nil

        // The next API call will fail if there is a function call but no corresponding tool call.
        for message in modalManager.messages {
            if case .function_call(let functionCall) = message.messageType {
                fnCall = functionCall
                toolCallId = functionCall.id
                appContext = message.appContext
            } else if case .tool_call(let functionCall) = message.messageType, functionCall.id == toolCallId {
                // Marking as finished
                fnCall = nil
                toolCallId = nil
                appContext = nil
            }
        }

        if let fnCall = fnCall {
            DispatchQueue.main.async {
                modalManager.appendToolError("Function was canceled", functionCall: fnCall, appContext: appContext)
            }
        }
    }
}
