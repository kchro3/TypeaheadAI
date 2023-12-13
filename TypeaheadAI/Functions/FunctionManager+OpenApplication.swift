//
//  FunctionManager+OpenApplication.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func openApplication(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let bundleIdentifier = functionCall.stringArg("bundleIdentifier") else {
            await modalManager.setError("Failed to open application", appContext: appContext)
            return
        }

        await modalManager.appendFunction("Opening \(bundleIdentifier)...", functionCall: functionCall, appContext: appContext)

        guard appInfo?.apps[bundleIdentifier] != nil else {
            await modalManager.appendToolError("This app cannot be opened by Typeahead", functionCall: functionCall, appContext: appContext)
            return
        }

        await modalManager.closeModal()

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            // Activate the app, bringing it to the foreground
            NSWorkspace.shared.open(url)
            await modalManager.appendTool("Opened", functionCall: functionCall, appContext: appContext)
            try await Task.sleep(for: .seconds(1))
            await modalManager.showModal()
            try await modalManager.continueReplying()
        } else {
            await modalManager.showModal()
            await modalManager.appendToolError("Failed to open", functionCall: functionCall, appContext: appContext)
        }
    }
}
