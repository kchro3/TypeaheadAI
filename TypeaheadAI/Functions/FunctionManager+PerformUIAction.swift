//
//  FunctionManager+PerformUIAction.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import AppKit
import Foundation

struct Action: Identifiable, Codable {
    let id: String
    let narration: String
    let inputText: String?
    let pressEnter: Bool?
}

extension FunctionCall {
    func getAction() -> Action? {
        guard let id = self.stringArg("id"),
              let narration = self.stringArg("narration") else {
            return nil
        }

        return Action(
            id: id,
            narration: narration,
            inputText: self.stringArg("inputText"),
            pressEnter: self.boolArg("pressEnter")
        )
    }
}

extension FunctionManager: CanSimulateEnter, CanGetUIElements {

    func performUIAction(_ functionCall: FunctionCall, appInfo: AppInfo?, modalManager: ModalManager) async throws {
        let appContext = appInfo?.appContext

        guard let action = functionCall.getAction(),
              let elementMap = appInfo?.elementMap else {
            await modalManager.setError("Failed to perform UI action", appContext: appContext)
            return
        }

        narrate(text: action.narration)
        await modalManager.appendFunction(
            "Performing action: \(action)...",
            functionCall: functionCall,
            appContext: appInfo?.appContext
        )

        try await Task.sleep(for: .seconds(3))
        try Task.checkCancellation()

        await modalManager.closeModal()

        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
        }

        try Task.checkCancellation()

        guard let axElement = elementMap[action.id] else {
            // TERMINATE on invalid action
            await modalManager.showModal()
            await modalManager.appendToolError("No such element \(action.id)", functionCall: functionCall, appContext: appContext)
            return
        }

        _ = AXUIElementPerformAction(axElement, "AXScrollToVisible" as CFString)
        try await Task.sleep(for: .milliseconds(100))
        try Task.checkCancellation()

        do {
            try await focus(on: axElement)
        } catch {
            // TERMINATE on failure
            await modalManager.showModal()
            await modalManager.appendToolError("Action failed...", functionCall: functionCall, appContext: appContext)
            return
        }

        if let inputText = action.inputText, let role = axElement.stringValue(forAttribute: kAXRoleAttribute) {
            if role == "AXComboBox" {
                if let parent = axElement.parent(),
                   let axList = parent.children().first(where: { child in child.stringValue(forAttribute: kAXRoleAttribute) == "AXList" }),
                   let serializedList = UIElementVisitor.visit(element: axList)?.serialize(
                    isIndexed: false,
                    excludedActions: ["AXShowMenu", "AXScrollToVisible", "AXCancel", "AXRaise"]
                   ),
                   let pickResult = pickFromList(axElement: axList, value: inputText) {
                    if pickResult != .success {
                        print(serializedList)
                        // TERMINATE on failure
                        await modalManager.showModal()

                        await modalManager.appendToolError("Action failed... Could not find \(inputText) in dropdown menu", functionCall: functionCall, appContext: appContext)

                        return
                    }
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(inputText, forType: .string)
                    try await Task.sleep(for: .milliseconds(100))
                    try Task.checkCancellation()

                    try await simulatePaste()

                    if action.pressEnter ?? false {
                        try await simulateEnter()
                    }
                }
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(inputText, forType: .string)
                try await Task.sleep(for: .milliseconds(100))
                try Task.checkCancellation()

                try await simulateSelectAll()
                try await simulatePaste()

                if action.pressEnter ?? false {
                    try await simulateEnter()
                }
            }
        }

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

        try Task.checkCancellation()

        let newAppInfo = AppInfo(
            appContext: appInfo?.appContext,
            elementMap: newElementMap,
            apps: appInfo?.apps ?? [:]
        )

        DispatchQueue.main.async {
            modalManager.cachedAppInfo = newAppInfo
        }

        Task {
            do {
                try await modalManager.continueReplying(appInfo: newAppInfo)
            } catch {
                await modalManager.setError(error.localizedDescription, appContext: appInfo?.appContext)
            }
        }
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
