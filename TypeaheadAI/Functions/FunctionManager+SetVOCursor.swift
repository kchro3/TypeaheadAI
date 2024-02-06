//
//  FunctionManager+SetVOCursor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/19/24.
//

import AppKit
import Foundation

extension FunctionManager {
    func setVOCursor(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws {
        let appContext = appInfo?.appContext

        guard case .saveFile(let id, let file) = try functionCall.parseArgs() else {
            throw ApiError.appError("Invalid app state")
        }

        guard let elementMap = appInfo?.elementMap,
              let savePanel = elementMap[id] else {
            throw ApiError.functionCallError(
                "Failed to save file",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        // Activate relevant app
        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
            try await Task.safeSleep(for: .milliseconds(100))
        }

        // Copy filename to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file, forType: .string)
        try await Task.safeSleep(for: .milliseconds(100))

        // Open file viewer
        try await simulateGoToFile()
        try await Task.safeSleep(for: .milliseconds(500))

        // Paste filename to file viewer
        try await simulatePaste()

        // Enter to save as filename
        try await simulateEnter()
        try await Task.safeSleep(for: .milliseconds(500))
        try await simulateEnter()
        try await Task.safeSleep(for: .seconds(1))

        // Check if there's a "Replace" dialog
        if let replaceButton = savePanel.findFirst(condition: {
            $0.stringValue(forAttribute: kAXIdentifierAttribute) == "action-button-1"
        }) {
            _ = AXUIElementPerformAction(replaceButton, "AXPress" as CFString)
            try await Task.safeSleep(for: .seconds(1))
        }
    }
}
