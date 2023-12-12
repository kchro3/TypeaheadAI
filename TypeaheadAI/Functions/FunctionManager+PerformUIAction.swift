//
//  FunctionManager+PerformUIAction.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

extension FunctionManager {

    func performUIAction(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let serializedActions = functionCall.args["actions"],
              let jsonData = serializedActions.data(using: .utf8),
              let actions = try? JSONDecoder().decode([Action].self, from: jsonData),
              let elementMap = appInfo?.elementMap else {
            await modalManager.setError("Failed to perform UI action", appContext: appContext)
            return
        }

        await modalManager.appendFunction(
            "Performing actions: \(actions)...",
            functionCall: functionCall,
            appContext: appInfo?.appContext
        )

        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
        }

        await modalManager.closeModal()

        var isMutated = false
        for action in actions {
            print(action)
            guard let axElement = elementMap[action.id] else {
                // TERMINATE on invalid action
                await modalManager.showModal()
                await modalManager.appendToolError("No such element \(action.id)", functionCall: functionCall, appContext: appContext)
                return
            }

            let result = AXUIElementPerformAction(axElement, action.action as CFString)

            guard result == .success else {
                // TERMINATE on failure
                await modalManager.showModal()

                if result == .actionUnsupported {
                    await modalManager.appendToolError("No such action \(action)", functionCall: functionCall, appContext: appContext)
                } else {
                    await modalManager.appendToolError("Action could not be performed", functionCall: functionCall, appContext: appContext)
                }

                return
            }

            if let textToPaste = action.textToPaste {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(textToPaste, forType: .string)
                try await Task.sleep(for: .seconds(1))

                try await simulateSelectAll()
                try await simulatePaste()
                isMutated = true
            }

            try await Task.sleep(for: .seconds(1))
        }

        // NOTE: Probably a good idea, but it doesn't work well in practice...
//        if isMutated {
//            print("Getting current state")
//            let (newUIElement, _) = getUIElements(appContext: appInfo?.appContext)
//            if let serializedUIElement = newUIElement?.serialize(isIndexed: false) {
//                await modalManager.appendTool(
//                    "Updated state: \(serializedUIElement)",
//                    functionCall: functionCall,
//                    appContext: appInfo?.appContext
//                )
//
//                await modalManager.showModal()
//                try await modalManager.continueReplying()
//            } else {
//                await modalManager.appendToolError(
//                    "Could not fetch new UI state...",
//                    functionCall: functionCall,
//                    appContext: appInfo?.appContext
//                )
//
//                await modalManager.showModal()
//            }
//        } else {
        await modalManager.appendTool(
            "Completed actions successfully",
            functionCall: functionCall,
            appContext: appInfo?.appContext
        )

        await modalManager.showModal()
        try await modalManager.continueReplying()
    }
}
