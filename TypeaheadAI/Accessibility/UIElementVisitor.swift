//
//  UIElementVisitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/30/23.
//

import AppKit
import Foundation

class UIElementVisitor {
    private static let defaultExclusiveRoles = ["AXSheet", "AXApplicationDialog"]  // If a child is one of these types, then other children are ignored.

    static func visit(
        element: AXUIElement,
        idGenerator: (() -> Int)? = nil,
        callback: ((String, AXUIElement) -> Void)? = nil
    ) -> UIElement? {
        guard let role = element.role() else {
            return nil
        }

        if role == "AXGroup" && element.children().count == 1 {
            return visit(
                element: element.children()[0],
                idGenerator: idGenerator,
                callback: callback
            )
        }

        var title: String? = nil
        if let titleAttr = element.stringValue(forAttribute: kAXTitleAttribute), !titleAttr.isEmpty {
            title = titleAttr
        } else if let titleUIElement = element.subelement(forAttribute: kAXTitleUIElementAttribute),
                  titleUIElement.stringValue(forAttribute: kAXRoleAttribute) == "AXStaticText",
                  let titleAttr = titleUIElement.stringValue(forAttribute: kAXValueAttribute),
                  !titleAttr.isEmpty {
            title = titleAttr
        }

        var description: String? = nil
        if let descAttr = element.stringValue(forAttribute: kAXDescriptionAttribute), !descAttr.isEmpty {
            description = descAttr
        }

        var label: String? = nil
        if let labelAttr = element.stringValue(forAttribute: kAXLabelValueAttribute), !labelAttr.isEmpty {
            label = labelAttr
        }

        var value: String? = nil
        if let valueAttr = element.stringValue(forAttribute: kAXValueAttribute), !valueAttr.isEmpty {
            value = valueAttr
        }

        var domId: String? = nil
        if let domAttr = element.stringValue(forAttribute: "AXDOMIdentifier"), !domAttr.isEmpty {
            domId = domAttr
        }

        // Recurse through the children
        var children: [UIElement] = []
        for axChild in element.children() {
            if let child = visit(
                element: axChild,
                idGenerator: idGenerator,
                callback: callback
            ) {
                if UIElementVisitor.defaultExclusiveRoles.contains(child.role) {
                    children = [child]
                    break
                } else {
                    children.append(child)
                }
            }
        }

        let uiElement = UIElement(
            id: idGenerator?() ?? 0,
            role: role,
            title: title,
            description: description,
            label: label,
            value: value,
            link: element.value(forAttribute: kAXURLAttribute) as? URL,
            point: element.pointValue(forAttribute: kAXPositionAttribute),
            size: element.sizeValue(forAttribute: kAXSizeAttribute),
            domId: domId,
            domClasses: nil,
            enabled: element.boolValue(forAttribute: kAXEnabledAttribute),
            identifier: element.stringValue(forAttribute: kAXIdentifierAttribute),
            actions: element.actions(),
            parentRole: element.parent()?.stringValue(forAttribute: kAXRoleAttribute),
            children: children,
            attributes: element.attributes()
        )

        callback?(uiElement.shortId, element)
        return uiElement
    }
}
