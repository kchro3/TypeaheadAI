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
    let action: String
    let narration: String
    let inputText: String?
    let pressEnter: Bool?
}

extension FunctionCall {
    func getActions() -> [Action] {
        guard let serializedActions = self.stringArg("actions"),
              let jsonData = serializedActions.data(using: .utf8),
              let actions = try? JSONDecoder().decode([Action].self, from: jsonData) else {
            return []
        }

        return actions
    }
}

extension FunctionManager: CanSimulateEnter {

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

        try await Task.sleep(for: .seconds(3))
        try Task.checkCancellation()

        await modalManager.closeModal()

        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
        }

        for (index, action) in actions.enumerated() {
            print(index, action)
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

            var result: AXError? = nil
            if action.action == "<click>" {
                if axElement.actions().contains("AXPress") {
                    result = AXUIElementPerformAction(axElement, "AXPress" as CFString)
                } else if let size = axElement.sizeValue(forAttribute: kAXSizeAttribute),
                          let point = axElement.pointValue(forAttribute: kAXPositionAttribute),
                          size.width * size.height > 1.0 {
                    // Simulate a mouse click event
                    let centerPoint = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
                    print("click on \(centerPoint)")
                    simulateMouseClick(at: centerPoint)
                    result = .success
                } else {
                    result = .actionUnsupported
                }
            } else {
                result = AXUIElementPerformAction(axElement, action.action as CFString)
            }

            try await Task.sleep(for: .milliseconds(100))
            try Task.checkCancellation()

            guard result == .success else {
                // TERMINATE on failure
                await modalManager.showModal()

                if result == .actionUnsupported {
                    await modalManager.appendToolError("Step \(index+1) failed because the action was invalid.", functionCall: functionCall, appContext: appContext)
                } else {
                    await modalManager.appendToolError("Step \(index+1) failed... (code: \(result?.rawValue ?? -1))", functionCall: functionCall, appContext: appContext)
                }

                return
            }

            if let inputText = action.inputText, let role = axElement.stringValue(forAttribute: kAXRoleAttribute) {
                if role == "AXComboBox" {
                    if let parent = axElement.parent(),
                       let axList = parent.children().first(where: { child in child.stringValue(forAttribute: kAXRoleAttribute) == "AXList" }),
                       let serializedList = UIElement(from: axList)?.serialize(isIndexed: false),
                       let pickResult = pickFromList(axElement: axList, value: inputText) {
                        if pickResult != .success {
                            print(serializedList)
                            // TERMINATE on failure
                            await modalManager.showModal()

                            await modalManager.appendToolError("Step \(index+1) failed... Could not find \(inputText) in dropdown menu", functionCall: functionCall, appContext: appContext)

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

    /// Super janky, but I need to click on a point & return the mouse back to its original position
    func simulateMouseClick(at point: CGPoint) {
        // Store the original mouse position
        let originalPosition = NSEvent.mouseLocation

        // Create a mouse down event
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }

        // Create a mouse up event
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }

        // Move the mouse back to the original position
        CGDisplayMoveCursorToPoint(CGMainDisplayID(), originalPosition)
    }
}
