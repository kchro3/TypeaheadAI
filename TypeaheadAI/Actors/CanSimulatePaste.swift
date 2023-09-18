//
//  CanSimulatePaste.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import Foundation
import Carbon.HIToolbox

protocol CanSimulatePaste {
    func simulatePaste(completion: @escaping () -> Void)
}

extension CanSimulatePaste {
    func simulatePaste(completion: @escaping () -> Void) {
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        cmdCDown.flags = [.maskCommand]
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key
        cmdCUp.flags = [.maskCommand]

        cmdCDown.post(tap: .cghidEventTap)
        cmdCUp.post(tap: .cghidEventTap)

        // Delay for the clipboard to update, then call the completion handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion()
        }
    }
}
