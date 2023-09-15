//
//  CanSimulatePaste.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/14/23.
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
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        cmdVDown.flags = [.maskCommand]
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key
        cmdVUp.flags = [.maskCommand]

        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)

        // Delay for the clipboard to paste, then call the completion handler
        // TODO: May need to tune the paste time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion()
        }
    }
}
