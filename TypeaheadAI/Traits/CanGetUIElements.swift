//
//  CanGetUIElements.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

protocol CanGetUIElements {
    func getUIElements(appContext: AppContext?) -> (UIElementTree?, ElementMap)
}

extension CanGetUIElements {
    func getUIElements(appContext: AppContext?) -> (UIElementTree?, ElementMap) {
        var element: AXUIElement? = nil
        if let appContext = appContext, let pid = appContext.pid {
            element = AXUIElementCreateApplication(pid)

            // Narrow down to the first (top-most) window
            if let windowElement = element?.children().first(where: {
                $0.stringValue(forAttribute: kAXRoleAttribute) == "AXWindow" &&
                !$0.children().isEmpty
            }) {
                element = windowElement
            }
        } else {
            element = AXUIElementCreateSystemWide()
        }

        if let element = element {
            return UIElementVisitor.visitIterative(element: element)
        } else {
            return (nil, ElementMap())
        }
    }
}
