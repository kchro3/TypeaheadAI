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

    func performUIAction(_ functionCall: FunctionCall, appInfo: AppInfo?) async throws {
        let appContext = appInfo?.appContext

        guard case .performUIAction(let action) = try functionCall.parseArgs(),
              let elementMap = appInfo?.elementMap else {
            throw ClientManagerError.appError("Invalid app state")
        }

        guard let axElement = elementMap[action.id] else {
            throw ClientManagerError.functionCallError(
                "No such element \(action.id)",
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        if let bundleIdentifier = appContext?.bundleIdentifier,
           let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            // Activate the app, bringing it to the foreground
            app.activate(options: [.activateIgnoringOtherApps])
            try await Task.safeSleep(for: .milliseconds(100))
        }

        _ = AXUIElementPerformAction(axElement, "AXScrollToVisible" as CFString)

        try await Task.safeSleep(for: .milliseconds(100))

        do {
            try await focus(on: axElement)
        } catch {
            throw ClientManagerError.functionCallError(
                error.localizedDescription,
                functionCall: functionCall,
                appContext: appInfo?.appContext
            )
        }

        if let inputText = action.inputText, let role = axElement.stringValue(forAttribute: kAXRoleAttribute) {
            if role == "AXComboBox" {
                if let parent = axElement.parent(),
                   let axList = parent.children().first(where: { child in child.stringValue(forAttribute: kAXRoleAttribute) == "AXList" }),
                   let serializedList = UIElementVisitor.visit(element: axList)?.serialize(isIndexed: false),
                   let pickResult = pickFromList(axElement: axList, value: inputText) {
                    if pickResult != .success {
                        print(serializedList)
                        throw ClientManagerError.functionCallError(
                            "Action failed... Could not find \(inputText) in dropdown menu",
                            functionCall: functionCall,
                            appContext: appInfo?.appContext
                        )
                    }
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(inputText, forType: .string)
                    try await Task.safeSleep(for: .milliseconds(100))

                    try await simulatePaste()

                    if action.pressEnter ?? false {
                        try await simulateEnter()
                    }
                }
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(inputText, forType: .string)
                try await Task.safeSleep(for: .milliseconds(100))

                try await simulateSelectAll()
                try await simulatePaste()

                if action.pressEnter ?? false {
                    try await simulateEnter()
                }
            }
        }

        try await Task.safeSleep(for: .seconds(2))
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
