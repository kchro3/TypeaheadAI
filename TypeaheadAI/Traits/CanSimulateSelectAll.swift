//
//  CanSimulateSelectAll.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/20/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulateSelectAll {
    func simulateSelectAll() async throws
}

extension CanSimulateSelectAll {
    func simulateSelectAll() async throws {
        // Post a Command-A keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_A), keyDown: false)!
        keyDown.flags = [.maskCommand]
        keyUp.flags = [.maskCommand]

        keyDown.post(tap: .cghidEventTap)
        try await Task.sleepSafe(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.sleepSafe(for: .milliseconds(200))
    }
}
