//
//  FunctionManager+PerformUIAction.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

struct Action: Codable {
    let id: String
    let action: String
    let inputText: String?
}

extension FunctionManager {

    func performUIAction(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let serializedActions = functionCall.stringArg("actions"),
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

        for action in actions {
            print(action)
            guard let axElement = elementMap[action.id] else {
                // TERMINATE on invalid action
                await modalManager.showModal()
                await modalManager.appendToolError("No such element \(action.id)", functionCall: functionCall, appContext: appContext)
                return
            }

            _ = AXUIElementPerformAction(axElement, "AXScrollToVisible" as CFString)
            try await Task.sleep(for: .milliseconds(100))
            let result = AXUIElementPerformAction(axElement, action.action as CFString)
            try await Task.sleep(for: .seconds(1))

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

            if let inputText = action.inputText, let role = axElement.stringValue(forAttribute: kAXRoleAttribute) {
                if role == "AXTextField" {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(inputText, forType: .string)
                    try await Task.sleep(for: .seconds(1))

                    try await simulateSelectAll()
                    try await simulatePaste()
                } else if role == "AXComboBox" {
                    if let parent = axElement.parent(),
                       let axList = parent.children().first(where: { child in child.stringValue(forAttribute: kAXRoleAttribute) == "AXList" }),
                       let serializedList = UIElement(from: axList)?.serialize(isIndexed: false),
                       let pickResult = pickFromList(axElement: axList, value: inputText) {
                        if pickResult != .success {
                            await modalManager.appendToolError("Could not find \(inputText) in \(serializedList)", functionCall: functionCall, appContext: appContext)
                        }
                    } else {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(inputText, forType: .string)
                        try await Task.sleep(for: .seconds(1))

                        try await simulatePaste()
                    }
                }
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

    /// Recursively traverse an AXList to select an option that matches the expected value.
    /// This is probably pretty brittle. We should try this out on a few use-cases
    private func pickFromList(axElement: AXUIElement, value: String) -> AXError? {
        guard axElement.stringValue(forAttribute: kAXValueAttribute) != value else {
            return AXUIElementPerformAction(axElement, "AXPress" as CFString)
        }

        for child in axElement.children() {
            if let result = pickFromList(axElement: child, value: value) {
                return result
            }
        }

        return nil
    }
}
