//
//  Functions.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/16/23.
//

import AppKit
import AVFoundation
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
    case array([JSONAny])

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
        } else if let arrayVal = try? container.decode([JSONAny].self) {
            self = .array(arrayVal)
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
        case .array(let arrayVal):
            try container.encode(arrayVal)
        }
    }
}

struct FunctionCall: Codable, Equatable {
    let id: String?
    let name: String
    var args: [String: JSONAny]

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

class FunctionManager: ObservableObject,
                       CanFetchAppContext,
                       CanSimulateSelectAll,
                       CanSimulateCopy,
                       CanSimulatePaste,
                       CanSimulateClose,
                       CanSimulateGoToFile,
                       CanFocusOnElement {

    @Published var isExecuting: Bool = false
    private var currentTask: Task<Void, Error>? = nil
    private var speaker = AVSpeechSynthesizer()

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

            case "open_file":
                do {
                    try await self?.openFile(functionCall, appInfo: appInfo, modalManager: modalManager)
                } catch {
                    modalManager.setError("Failed when opening file...", appContext: appContext)
                }

            case "save_file":
                do {
                    try await self?.saveFile(functionCall, appInfo: appInfo, modalManager: modalManager)
                } catch {
                    modalManager.setError("Failed when saving file...", appContext: appContext)
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

    @MainActor
    func cancelTask() {
        currentTask?.cancel()
        currentTask = nil
        isExecuting = false
    }

    func narrate(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.prefersAssistiveTechnologySettings = true
        speaker.speak(utterance)
    }
}
