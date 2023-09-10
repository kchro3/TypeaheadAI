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
}
