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
    let delayInMillis: Int
}

extension FunctionCall {
    func getAction() -> Action? {
        guard let id = self.stringArg("id"),
              let delayInMillis = self.intArg("delayInMillis"),
              let narration = self.stringArg("narration") else {
            return nil
        }

        return Action(
            id: id,
            narration: narration,
            inputText: self.stringArg("inputText"),
            pressEnter: self.boolArg("pressEnter"),
            delayInMillis: delayInMillis
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

        await modalManager.appendFunction(
            "Performing action: \(action)...",
            functionCall: functionCall,
            appContext: appInfo?.appContext
        )

        await modalManager.closeModal()

        try Task.checkCancellation()
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

        try Task.checkCancellation()
        _ = AXUIElementPerformAction(axElement, "AXScrollToVisible" as CFString)
        try await Task.sleep(for: .milliseconds(100))

        do {
            try Task.checkCancellation()
            try await focus(on: axElement)
        } catch {
            // TERMINATE on failure
            await modalManager.showModal()
            await modalManager.appendToolError("Action failed...", functionCall: functionCall, appContext: appContext)
            return
        }

        try Task.checkCancellation()
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

                    try Task.checkCancellation()
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

                try Task.checkCancellation()
                try await simulatePaste()

                if action.pressEnter ?? false {
                    try Task.checkCancellation()
                    try await simulateEnter()
                }
            }
        }

        try Task.checkCancellation()
        try await Task.sleep(for: .seconds(2))

        await modalManager.showModal()

        try Task.checkCancellation()
        let (newUIElement, newElementMap) = getUIElements(appContext: appInfo?.appContext)
        if let serializedUIElement = newUIElement?.serialize(
            excludedActions: ["AXShowMenu", "AXScrollToVisible", "AXCancel", "AXRaise"]
        ) {
            try Task.checkCancellation()
            await modalManager.appendTool(
                "Updated state: \(serializedUIElement)",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        } else {
            try Task.checkCancellation()
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

        await MainActor.run {
            modalManager.cachedAppInfo = newAppInfo
        }

        Task {
            do {
                try Task.checkCancellation()
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
