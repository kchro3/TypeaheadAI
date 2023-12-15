//
//  CanGetUIElements.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

protocol CanGetUIElements {
    func getRootElement(appContext: AppContext?) -> AXUIElement?

    func getUIElements(appContext: AppContext?) -> (UIElement?, ElementMap)

    func getUIElements(element: AXUIElement?) -> (UIElement?, ElementMap)
}

extension CanGetUIElements {
    func getRootElement(appContext: AppContext?) -> AXUIElement? {
        var element: AXUIElement? = nil
        if let appContext = appContext, let pid = appContext.pid {
            element = AXUIElementCreateApplication(pid)
        } else {
            element = AXUIElementCreateSystemWide()
        }

        return element
    }

    func getUIElements(element: AXUIElement?) -> (UIElement?, ElementMap) {
        var elementMap = ElementMap()
        if let element = element, let uiElement = UIElement(from: element, callback: { uuid, element in
            elementMap[uuid] = element
        }) {
            return (uiElement, elementMap)
        } else {
            return (nil, ElementMap())
        }
    }

    func getUIElements(appContext: AppContext?) -> (UIElement?, ElementMap) {
        let element = getRootElement(appContext: appContext)
        return getUIElements(element: element)
    }
}
