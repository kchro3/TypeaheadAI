//
//  CanSimulatePaste.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulatePaste {
    func simulatePaste(flags: CGEventFlags?) async throws
}

extension CanSimulatePaste {
    func simulatePaste(flags: CGEventFlags? = nil) async throws {
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)!

        if let flags = flags {
            keyDown.flags = flags
            keyUp.flags = flags
        } else {
            keyDown.flags = [.maskCommand]
            keyUp.flags = [.maskCommand]
        }

        keyDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
    }
}
