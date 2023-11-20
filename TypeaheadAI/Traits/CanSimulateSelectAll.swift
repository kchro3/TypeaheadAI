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
        let cmdADown = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: true)! // a key
        let cmdAUp = CGEvent(keyboardEventSource: source, virtualKey: 0x00, keyDown: false)! // a key

        cmdADown.flags = [.maskCommand]
        cmdAUp.flags = [.maskCommand]

        cmdADown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(20))
        cmdAUp.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
    }
}
