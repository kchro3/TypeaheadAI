//
//  FunctionManager+OpenURL.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func openURL(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws {
        guard case .openURL(let url) = try functionCall.parseArgs() else {
            throw ClientManagerError.appError("Invalid app state")
        }

        guard let url = URL(string: url) else {
            throw ClientManagerError.functionCallError(
                "URL not found", 
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        NSWorkspace.shared.open(url)        
        try await Task.safeSleep(for: .seconds(5))
    }
}
