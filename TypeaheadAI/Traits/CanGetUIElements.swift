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
        } else {
            element = AXUIElementCreateSystemWide()
        }

        var elementMap = ElementMap()
        if let element = element, let uiElement = UIElement(from: element, callback: { uuid, element in
            elementMap[uuid] = element
        }) {
            return (uiElement, elementMap)
        } else {
            return (nil, ElementMap())
        }
    }
}