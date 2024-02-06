//
//  ApiError.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 2/5/24.
//

import Foundation

enum ApiError: LocalizedError {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
    case appError(_ message: String)
    case networkError(_ message: String)
    case corruptedDataError(_ message: String)
    case signInRequired(_ message: String)

    // LLaMA errors
    case modelNotFound(_ message: String)
    case modelNotLoaded(_ message: String)
    case modelDirectoryNotAuthorized(_ message: String)
    case modelFailed(_ message: String)

    // FunctionManager errors
    case functionParsingError(_ message: String)
    case functionArgParsingError(_ message: String)
    case functionCallError(_ message: String, functionCall: FunctionCall, appContext: AppContext?)
    case functionOnFocusError(_ message: String)

    var errorDescription: String {
        switch self {
        case .badRequest(let message): return message
        case .retriesExceeded(let message): return message
        case .clientError(let message): return message
        case .serverError(let message): return message
        case .appError(let message): return message
        case .networkError(let message): return message
        case .corruptedDataError(let message): return message
        case .signInRequired(let message): return message

            // LLaMA model errors
        case .modelNotFound(let message): return message
        case .modelNotLoaded(let message): return message
        case .modelDirectoryNotAuthorized(let message): return message
        case .modelFailed(let message): return message

            // FunctionManager errors
        case .functionParsingError(let message): return message
        case .functionArgParsingError(let message): return message
        case .functionCallError(let message, _, _): return message
        case .functionOnFocusError(let message): return message
        }
    }
}
