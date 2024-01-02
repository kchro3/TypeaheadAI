//
//  CanSimulateGoToFile.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/27/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulateGoToFile {
    func simulateGoToFile() async throws
}

extension CanSimulateGoToFile {
    func simulateGoToFile() async throws {
        // Post a Shift-Command-G keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_G), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_G), keyDown: false)!
        keyDown.flags = [.maskShift, .maskCommand]
        keyUp.flags = [.maskShift, .maskCommand]

        keyDown.post(tap: .cghidEventTap)
        try await Task.sleepSafe(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.sleepSafe(for: .milliseconds(200))
    }
}
