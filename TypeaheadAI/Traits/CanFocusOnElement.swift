//
//  CanFocusOnElement.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/27/23.
//

import AppKit
import Foundation

protocol CanFocusOnElement {
    func focus(on: AXUIElement, functionCall: FunctionCall, appContext: AppContext?) async throws
}

extension CanFocusOnElement {
    func focus(on axElement: AXUIElement, functionCall: FunctionCall, appContext: AppContext?) async throws {
        var result: AXError? = nil
        if axElement.actions().contains("AXPress") {
            result = AXUIElementPerformAction(axElement, "AXPress" as CFString)
            if result == .cannotComplete {
                // Retry the action after one second
                try await Task.safeSleep(for: .seconds(1))
                result = AXUIElementPerformAction(axElement, "AXPress" as CFString)
            }
        } else if let center = axElement.getCenter() {
            // Simulate a mouse click event
            simulateMouseClick(at: center)
            result = .success
        } else {
            result = .actionUnsupported
        }

        try await Task.safeSleep(for: .milliseconds(100))
        guard result == .success else {
            throw ApiError.functionCallError(
                "Action failed (code: \(result?.rawValue ?? -1))",
                functionCall: functionCall,
                appContext: appContext
            )
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
