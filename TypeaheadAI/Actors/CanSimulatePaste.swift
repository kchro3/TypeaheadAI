//
//  CanSimulatePaste.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulatePaste {
    func simulatePaste(flags: CGEventFlags?)
}

extension CanSimulatePaste {
    func simulatePaste(flags: CGEventFlags? = nil) {
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key

        if let flags = flags {
            cmdVDown.flags = flags
            cmdVUp.flags = flags
        } else {
            cmdVDown.flags = [.maskCommand]
            cmdVUp.flags = [.maskCommand]
        }

        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)
    }
}
