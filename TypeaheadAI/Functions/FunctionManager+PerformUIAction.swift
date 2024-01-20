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
    let setFocus: Bool?
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
            pressEnter: self.boolArg("pressEnter"),
            setFocus: self.boolArg("setFocus")
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

        try await focus(on: axElement, functionCall: functionCall, appContext: appInfo?.appContext)

        try await Task.safeSleep(for: .milliseconds(200))

        if let inputText = action.inputText, let role = axElement.stringValue(forAttribute: kAXRoleAttribute) {
            if role == "AXComboBox" || role == "AXPopUpButton" {
                if let parent = axElement.parent(),
                   let axList = parent.findFirst(condition: { $0.stringValue(forAttribute: kAXRoleAttribute) == "AXList" }),
                   let result = axList.findFirst(condition: { $0.stringValue(forAttribute: kAXValueAttribute) == inputText }) {

                    try await focus(on: result, functionCall: functionCall, appContext: appInfo?.appContext)
                } else {
                    print("Could not find element in dropdown window")
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
}
