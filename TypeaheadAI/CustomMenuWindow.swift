//
//  CustomMenuWindow.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import Foundation
import Cocoa

class CustomMenuWindow: NSView {
    /// This override makes it possible for the window to become the
    /// first responder, which makes it responsive to command-C events.
    override var canBecomeKeyView: Bool {
        return true
    }
}

