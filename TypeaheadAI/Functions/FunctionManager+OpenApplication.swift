//
//  FunctionManager+OpenApplication.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func openApplication(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws {
        guard case .openApplication(let bundleIdentifier) = try functionCall.parseArgs() else {
            throw ApiError.appError("Invalid app state")
        }

        guard appInfo?.apps[bundleIdentifier] != nil else {
            throw ApiError.functionCallError(
                "This app cannot be opened by Typeahead",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw ApiError.functionCallError(
                "Failed to open \(bundleIdentifier)",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        // Activate the app, bringing it to the foreground
        try Task.checkCancellation()
        NSWorkspace.shared.open(url)
        
        try await Task.safeSleep(for: .seconds(2))
    }
}
