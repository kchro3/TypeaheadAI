//
//  FunctionManager+OpenFile.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/26/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func openFile(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws {
        let appContext = appInfo?.appContext

        guard case .openFile(let file) = try functionCall.parseArgs() else {
            throw ClientManagerError.appError("Invalid app state")
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

        // Select the file
        try await simulateGoToFile()
        try await Task.safeSleep(for: .seconds(1))

        // Paste filename to file search field
        try await simulatePaste()
        try await Task.safeSleep(for: .seconds(1))

        // Enter twice to pick and attach file
        try await simulateEnter()
        try await Task.safeSleep(for: .seconds(1))
        try await simulateEnter()
        try await Task.safeSleep(for: .seconds(2))
    }
}
