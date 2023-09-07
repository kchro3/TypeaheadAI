//
//  CustomModalWindow.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/2/23.
//

import Foundation
import Cocoa

class CustomModalWindow: NSWindow {
    /// This override makes it possible for the window to become the
    /// first responder, which makes it responsive to command-C events.
    override var canBecomeKey: Bool {
        return true
    }
}