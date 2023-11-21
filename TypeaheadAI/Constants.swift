//
//  Constants.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let specialCopy = KeyboardShortcuts.Name("specialCopy", default: Shortcut(.c, modifiers: [.command, .control]))
    static let specialPaste = KeyboardShortcuts.Name("specialPaste", default: Shortcut(.v, modifiers: [.command, .control]))
    static let specialCut = KeyboardShortcuts.Name("specialCut", default: Shortcut(.x, modifiers: [.command, .control]))

    static let chatNew = KeyboardShortcuts.Name("chatNew", default: Shortcut(.n, modifiers: [.command, .control]))
    static let chatOpen = KeyboardShortcuts.Name("chatOpen", default: Shortcut(.a, modifiers: [.command, .control]))
}

extension KeyboardShortcuts.Name: CaseIterable {
    public static let allCases: [Self] = [
        .specialCopy,
        .specialPaste,
        .specialCut,
        .chatNew,
        .chatOpen,
    ]
}
