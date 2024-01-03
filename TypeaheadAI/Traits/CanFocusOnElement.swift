//
//  CanFocusOnElement.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/27/23.
//

import AppKit
import Foundation

protocol CanFocusOnElement {
    func focus(on: AXUIElement) async throws
}

extension CanFocusOnElement {
    func focus(on axElement: AXUIElement) async throws {
        var result: AXError? = nil
        if axElement.actions().contains("AXPress") {
            result = AXUIElementPerformAction(axElement, "AXPress" as CFString)
            if result == .cannotComplete {
                // Retry the action after one second
                try await Task.safeSleep(for: .seconds(1))
                result = AXUIElementPerformAction(axElement, "AXPress" as CFString)
            }
        } else if let size = axElement.sizeValue(forAttribute: kAXSizeAttribute),
                  let point = axElement.pointValue(forAttribute: kAXPositionAttribute),
                  size.width * size.height > 1.0 {
            // Simulate a mouse click event
            let centerPoint = CGPoint(x: point.x + size.width / 2, y: point.y + size.height / 2)
            simulateMouseClick(at: centerPoint)
            result = .success
        } else {
            result = .actionUnsupported
        }

        try await Task.safeSleep(for: .milliseconds(100))
        guard result == .success else {
            throw ClientManagerError.appError("Action failed (code: \(result?.rawValue ?? -1))")
        }
    }

    /// Super janky, but I need to click on a point & return the mouse back to its original position
    private func simulateMouseClick(at point: CGPoint) {
        // Store the original mouse position
        let originalPosition = NSEvent.mouseLocation

        // Create a mouse down event
        if let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) {
            mouseDown.post(tap: .cghidEventTap)
        }

        // Create a mouse up event
        if let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) {
            mouseUp.post(tap: .cghidEventTap)
        }

        // Move the mouse back to the original position
        CGDisplayMoveCursorToPoint(CGMainDisplayID(), originalPosition)
    }
}
