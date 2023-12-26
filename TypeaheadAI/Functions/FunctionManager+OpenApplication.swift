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

        try Task.checkCancellation()
        await modalManager.closeModal()

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            await modalManager.showModal()
            await modalManager.appendToolError("Failed to open", functionCall: functionCall, appContext: appContext)
            return
        }

        // Activate the app, bringing it to the foreground
        NSWorkspace.shared.open(url)
        try Task.checkCancellation()

        let newAppContext = try await fetchAppContext()
        let (newUIElement, newElementMap) = getUIElements(appContext: newAppContext)
        guard let serializedUIElement = newUIElement?.serialize(
            excludedActions: ["AXShowMenu", "AXScrollToVisible", "AXCancel", "AXRaise"]
        ) else {
            await modalManager.showModal()
            await modalManager.appendToolError(
                "Could not capture app state",
                functionCall: functionCall,
                appContext: newAppContext
            )
            return
        }

        await modalManager.showModal()
        await modalManager.appendTool(
            "Updated state: \(serializedUIElement)",
            functionCall: functionCall,
            appContext: newAppContext
        )

        let newAppInfo = AppInfo(
            appContext: newAppContext,
            elementMap: newElementMap,
            apps: appInfo?.apps ?? [:]
        )

        try Task.checkCancellation()
        try await modalManager.continueReplying(appInfo: newAppInfo)
    }
}
