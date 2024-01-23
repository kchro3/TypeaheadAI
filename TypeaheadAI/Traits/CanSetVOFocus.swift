//
//  CanSetVOFocus.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/19/24.
//

import AppKit
import Carbon.HIToolbox
import Foundation

protocol CanSetVOFocus {
    func focusVO(on: AXUIElement, functionCall: FunctionCall, appContext: AppContext?) async throws
}

extension CanSetVOFocus {
    func focusVO(on axElement: AXUIElement, functionCall: FunctionCall, appContext: AppContext?) async throws {

        guard NSWorkspace.shared.isVoiceOverEnabled else {
            throw ClientManagerError.functionCallError("VoiceOver must be enabled", functionCall: functionCall, appContext: appContext)
        }

        _ = AXUIElementPerformAction(axElement, "AXScrollToVisible" as CFString)
        try await Task.safeSleep(for: .milliseconds(100))

        guard let center = axElement.getCenter() else {
            throw ClientManagerError.functionCallError("Failed to focus on element", functionCall: functionCall, appContext: appContext)
        }

        // Move the mouse to the center of the element
        CGWarpMouseCursorPosition(center)
        try await Task.safeSleep(for: .milliseconds(100))

        // Post a VO-Shift-F5 keystroke
        try await sendKeyShortcut([CGKeyCode(kVK_Control), CGKeyCode(kVK_Option), CGKeyCode(kVK_Shift), CGKeyCode(kVK_F5)])
    }

    /// NOTE: Sometimes we need to issue the keys manually. No idea why.
    private func sendKeyShortcut(_ keys: [CGKeyCode]) async throws {
        let source = CGEventSource(stateID: .hidSystemState)

        for key in keys {
            let keydown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)!
            keydown.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(50))
        }

        for key in keys.reversed() {
            let keyup = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)!
            keyup.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}
