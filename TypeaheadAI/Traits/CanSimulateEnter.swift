//
//  CanSimulateEnter.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/13/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulateEnter {
    func simulateEnter() async throws
}

extension CanSimulateEnter {
    func simulateEnter() async throws {
        // Post a Enter keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: true)!
        keyDown.flags = []

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Return), keyDown: false)!
        keyUp.flags = []

        keyDown.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(200))
    }
}
