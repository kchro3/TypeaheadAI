//
//  FunctionManager+OpenFile.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/26/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func openFile(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let file = functionCall.stringArg("file") else {
            await modalManager.setError("Failed to open file", appContext: appContext)
            return
        }

        await modalManager.appendFunction("Opening \(file)...", functionCall: functionCall, appContext: appContext)

        try Task.checkCancellation()
        await modalManager.closeModal()

        // Activate relevant app
        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
            try await Task.sleep(for: .milliseconds(100))
        }

        try Task.checkCancellation()

        // Copy filename to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(file, forType: .string)
        try await Task.sleep(for: .milliseconds(100))
        try Task.checkCancellation()

        // Select the file
        try await simulateGoToFile()
        try await Task.sleep(for: .seconds(1))

        // Paste filename to file search field
        try await simulatePaste()
        try await Task.sleep(for: .seconds(1))

        // Enter twice to pick and attach file
        try await simulateEnter()
        try await Task.sleep(for: .seconds(1))
        try await simulateEnter()
        try await Task.sleep(for: .seconds(2))

        await modalManager.showModal()

        let (newUIElement, newElementMap) = getUIElements(appContext: appInfo?.appContext)
        if let serializedUIElement = newUIElement?.serialize(
            excludedActions: ["AXShowMenu", "AXScrollToVisible", "AXCancel", "AXRaise"]
        ) {
            await modalManager.appendTool(
                "Updated state: \(serializedUIElement)",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        } else {
            await modalManager.appendToolError(
                "Could not capture app state",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        let newAppInfo = AppInfo(
            appContext: appInfo?.appContext,
            elementMap: newElementMap,
            apps: appInfo?.apps ?? [:]
        )

        Task {
            do {
                try await modalManager.continueReplying(appInfo: newAppInfo)
            } catch {
                await modalManager.setError(error.localizedDescription, appContext: appInfo?.appContext)
            }
        }
    }
}
