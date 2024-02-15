//
//  CanSimulateDictation.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/19/24.
//

import AppKit
import Foundation
import Carbon.HIToolbox

protocol CanSimulateDictation: CanExecuteShellScript {
    func simulateDictation() async throws

    func simulateStopDictation() async throws
}

extension CanSimulateDictation {
    func simulateDictation() async throws {
        let isGlobeKeyDictation = try? await executeShellScript(
            url: "/usr/bin/defaults",
            script: ["read", "com.apple.HIToolbox", "AppleFnUsageType"]
        )

        // NOTE: Test on Mei's Macbook Pro.

        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0xB0), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(0xB0), keyDown: false)!

        keyDown.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(200))
    }

    func simulateStopDictation() async throws {
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Escape), keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Escape), keyDown: false)!

        keyDown.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.safeSleep(for: .milliseconds(200))
    }
}
