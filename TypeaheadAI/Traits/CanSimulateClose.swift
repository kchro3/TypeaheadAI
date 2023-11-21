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
        let cmdWDown = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: true)! // w key
        let cmdWUp = CGEvent(keyboardEventSource: source, virtualKey: 0x0D, keyDown: false)! // w key
        cmdWDown.flags = [.maskCommand]
        cmdWUp.flags = [.maskCommand]

        cmdWDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(20))
        cmdWUp.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
    }
}
