//
//  CanGetUIElements.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

protocol CanGetUIElements {
    func getUIElements(appContext: AppContext?) -> (UIElement?, ElementMap)
}

extension CanGetUIElements {
    func getUIElements(appContext: AppContext?) -> (UIElement?, ElementMap) {
        var element: AXUIElement? = nil
        if let appContext = appContext, let pid = appContext.pid {
            element = AXUIElementCreateApplication(pid)

            if let topMostElement = element?.topMost() {
                print(topMostElement.serialize() ?? "could not serialize")
                element = topMostElement
            }

//            // Narrow down to the first (top-most) window
//            if let windowElement = element?.children().first(where: {
//                $0.stringValue(forAttribute: kAXRoleAttribute) == "AXWindow" &&
//                !$0.children().isEmpty
//            }) {
//                element = windowElement
//            }
        } else {
            element = AXUIElementCreateSystemWide()
        }

        var elementId = 0
        var elementMap = ElementMap()
        if let element = element,
           let uiElement = UIElement(
            from: element,
            idGenerator: {
                elementId += 1
                return elementId
            },
            callback: { uuid, element in elementMap[uuid] = element }) {
            return (uiElement, elementMap)
        } else {
            return (nil, ElementMap())
        }
    }
}
