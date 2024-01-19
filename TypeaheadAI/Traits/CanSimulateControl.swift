//
//  CanSimulateControl.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/18/24.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulateControl {
    func simulateControl() async throws
}

extension CanSimulateControl {
    func simulateControl() async throws {
        // Post a Control keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Control), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Control), keyDown: false)!

        keyDown.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(200))
    }
}
