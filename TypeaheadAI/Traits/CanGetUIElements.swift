//
//  CanGetUIElements.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

/// Some apps have multiple windows and should be parsed together
let excludedBundleIds = [
    "com.macpaw.CleanMyMac4"
]

protocol CanGetUIElements {
    func getUIElements(appContext: AppContext?, inFocus: Bool) -> (UIElementTree?, ElementMap)
}

extension CanGetUIElements {
    func getUIElements(appContext: AppContext?, inFocus: Bool = false) -> (UIElementTree?, ElementMap) {
        var element: AXUIElement? = nil
        if let appContext = appContext, let pid = appContext.pid {
            element = AXUIElementCreateApplication(pid)

            if inFocus, NSWorkspace.shared.isVoiceOverEnabled, let focusedElement = element?.subelement(forAttribute: kAXFocusedUIElementAttribute) {
                element = focusedElement
            } else if let windowElement = getFirstTopMostWindow(element: element, appContext: appContext) {
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

    private func getFirstTopMostWindow(
        element: AXUIElement?,
        appContext: AppContext
    ) -> AXUIElement? {
        if let window = element?.children().first(where: {
            $0.stringValue(forAttribute: kAXRoleAttribute) == "AXWindow" &&
            !$0.children().isEmpty
        }), let bundleIdentifier = appContext.bundleIdentifier,
           !excludedBundleIds.contains(bundleIdentifier) {
            return window
        } else {
            return nil
        }
    }
}
