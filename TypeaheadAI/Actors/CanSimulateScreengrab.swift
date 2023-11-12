//
//  CanSimulateScreengrab.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/9/23.
//

import Cocoa
import Foundation

enum ScreengrabError: Error {
    case eventSourceCreationFailed
}

protocol CanSimulateScreengrab {
    func simulateScreengrab(completion: @escaping () -> Void) throws
    func simulateScreengrabSync() throws
}

extension CanSimulateScreengrab {
    func simulateScreengrab(completion: @escaping () -> Void) throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw ScreengrabError.eventSourceCreationFailed
        }

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x55, keyDown: true)!
        down.flags = [.maskCommand, .maskControl, .maskShift]
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x55, keyDown: false)!
        up.flags = [.maskCommand, .maskControl, .maskShift]

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        completion()
    }

    func simulateScreengrabSync() throws {
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw ScreengrabError.eventSourceCreationFailed
        }

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x55, keyDown: true)!
        down.flags = [.maskCommand, .maskControl, .maskShift]
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x55, keyDown: false)!
        up.flags = [.maskCommand, .maskControl, .maskShift]

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
