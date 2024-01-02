//
//  CanSimulateClose.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/20/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulateClose {
    func simulateClose() async throws
}

extension CanSimulateClose {
    func simulateClose() async throws {
        // Post a Command-W keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_W), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_W), keyDown: false)!
        keyDown.flags = [.maskCommand]
        keyUp.flags = [.maskCommand]

        keyDown.post(tap: .cghidEventTap)
        try await Task.sleepSafe(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.sleepSafe(for: .milliseconds(200))
    }
}
