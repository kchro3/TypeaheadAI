//
//  Constants.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let specialCopy = KeyboardShortcuts.Name("specialCopy", default: Shortcut(.c, modifiers: [.command, .option]))
    static let specialPaste = KeyboardShortcuts.Name("specialPaste", default: Shortcut(.v, modifiers: [.command, .option]))
    static let specialRecord = KeyboardShortcuts.Name("specialRecord", default: Shortcut(.r, modifiers: [.command, .option]))
    static let specialVision = KeyboardShortcuts.Name("specialVision", default: Shortcut(.o, modifiers: [.command, .option]))

    static let chatNew = KeyboardShortcuts.Name("chatNew", default: Shortcut(.n, modifiers: [.command, .option]))
    static let chatOpen = KeyboardShortcuts.Name("chatOpen", default: Shortcut(.space, modifiers: [.command, .option]))

    static let cancelTasks = KeyboardShortcuts.Name("cancelTasks", default: Shortcut(.escape, modifiers: [.command]))
}

extension KeyboardShortcuts.Name: CaseIterable {
    public static let allCases: [Self] = [
        .specialCopy,
        .specialPaste,
        .specialRecord,
        .specialVision,
        .chatNew,
        .chatOpen,
        .cancelTasks
    ]
}
