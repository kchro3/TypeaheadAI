//
//  FunctionManager+SaveFile.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/27/23.
//

import AppKit
import Foundation

extension FunctionManager {
    func saveFile(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let id = functionCall.stringArg("id"),
              let file = functionCall.stringArg("file"),
              let elementMap = appInfo?.elementMap,
              let savePanel = elementMap[id] else {
            await modalManager.setError("Failed to save file", appContext: appContext)
            return
        }

        await modalManager.appendFunction("Saving \(file)...", functionCall: functionCall, appContext: appContext)

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

        // Open file viewer
        try await simulateGoToFile()
        try await Task.sleep(for: .milliseconds(500))

        // Paste filename to file viewer
        try await simulatePaste()

        // Enter to save as filename
        try await simulateEnter()
        try await Task.sleep(for: .milliseconds(500))
        try await simulateEnter()
        try await Task.sleep(for: .seconds(1))

        // Check if there's a "Replace" dialog
        if let replaceButton = savePanel.findFirst(condition: {
            $0.stringValue(forAttribute: kAXIdentifierAttribute) == "action-button-1"
        }) {
            print("found replace button")
            _ = AXUIElementPerformAction(replaceButton, "AXPress" as CFString)
            try await Task.sleep(for: .seconds(1))
        } else {
            print("no replace button found")
        }

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
