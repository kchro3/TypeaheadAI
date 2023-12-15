//
//  CanSimulateCopy.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Carbon.HIToolbox
import Foundation

enum CanSimulateCopyError: Error {
    case noChangesDetected
}

protocol CanSimulateCopy {
    func simulateCopy() async throws
}

extension CanSimulateCopy {
    func simulateCopy() async throws {
        // Post a Command-C keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true)!
        keyDown.flags = [.maskCommand]
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false)!
        keyUp.flags = [.maskCommand]

        let changeCount = NSPasteboard.general.changeCount
        keyDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(20))
        keyUp.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(200))
        if changeCount == NSPasteboard.general.changeCount {
            throw CanSimulateCopyError.noChangesDetected
        }
    }

    func getMarkdownFromPasteboard() throws -> String? {
        if let htmlString = NSPasteboard.general.string(forType: .html),
           let sanitizedHTML = try? htmlString.sanitizeHTML() {
            return sanitizedHTML.renderXMLToMarkdown()
        } else {
            return nil
        }
    }
}
