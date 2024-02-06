//
//  FunctionManager+FocusUIElement.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/22/24.
//

import AppKit
import Foundation

extension FunctionManager: CanSimulateControl {

    func focusUIElement(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws {

        guard case .focusUIElement(let idOpt, let errorMessage) = try functionCall.parseArgs(),
              let elementMap = appInfo?.elementMap else {
            throw ApiError.appError("Invalid app state")
        }
        
        if let errorMessage = errorMessage {
            throw ApiError.functionCallError(
                errorMessage,
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        guard let elementId = idOpt else {
            throw ApiError.functionCallError(
                "Missing element ID",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        guard let axElement = elementMap[elementId] else {
            throw ApiError.functionCallError(
                "No such element \(elementId)",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        try Task.checkCancellation()
        
        if let bundleIdentifier = appInfo?.appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
            try await Task.safeSleep(for: .milliseconds(100))
        }

        try await simulateControl()
        try await focusVO(on: axElement, functionCall: functionCall, appContext: appInfo?.appContext)
    }
}
