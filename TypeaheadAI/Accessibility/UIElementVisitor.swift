//
//  UIElementVisitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/30/23.
//

import AppKit
import Foundation

class UIElementVisitor {
    private static let maxChildren = 25
    private static let defaultExclusiveRoles = [
        "AXSheet",
    ]  // If a child is one of these types, then other children are ignored.

    static func visitIterative(
        element: AXUIElement
    ) -> (UIElementTree?, ElementMap) {
        var stack: [(String?, AXUIElement)] = [(nil, element)]

        // Iteratively construct a UIElementTree
        var uiElements: [String : UIElement] = [:]
        var root: UIElement? = nil
        var hierarchy: [String : [String]] = [:]

        var elementMap = ElementMap()
        var count = 0

        while let (parentId, child) = stack.popLast() {
            guard let role = child.role() else {
                continue
            }

            // Optimization to collapse deeply nested AXGroup's
            let children = child.children(maxChildren: maxChildren)
            if role == "AXGroup", children.count == 1 {
                stack.append((parentId, children[0]))
                continue
            }

            count += 1
            let uiElement = UIElement(
                id: count,
                role: role,
                title: getTitle(child),
                description: getDescription(child),
                label: getLabel(child),
                value: getValue(child),
                link: child.value(forAttribute: kAXURLAttribute) as? URL,
                point: child.pointValue(forAttribute: kAXPositionAttribute),
                size: child.sizeValue(forAttribute: kAXSizeAttribute),
                domId: getDomId(child),
                domClasses: nil,
                enabled: child.boolValue(forAttribute: kAXEnabledAttribute),
                identifier: child.stringValue(forAttribute: kAXIdentifierAttribute),
                actions: child.actions(),
                parentRole: child.parent()?.stringValue(forAttribute: kAXRoleAttribute),
                attributes: child.attributes()
            )

            elementMap[uiElement.shortId] = child
            uiElements[uiElement.shortId] = uiElement
            hierarchy[uiElement.shortId] = []

            if root == nil {
                // Initialize root
                root = uiElement
            } else if let parentId = parentId, var childrenIds = hierarchy[parentId] {
                // Update children IDs
                childrenIds.append(uiElement.shortId)
                hierarchy[parentId] = childrenIds
            }

            for axChild in children {
                stack.append((uiElement.shortId, axChild))
            }
        }

        if let root = root {
            let tree = UIElementTree(uiElements: uiElements, root: root, hierarchy: hierarchy)
            return (tree, elementMap)
        } else {
            return (nil, elementMap)
        }
    }
}

extension UIElementVisitor {
    private static func getTitle(_ element: AXUIElement) -> String? {
        if let title = element.stringValue(forAttribute: kAXTitleAttribute), !title.isEmpty {
            return title
        } else if let titleUIElement = element.subelement(forAttribute: kAXTitleUIElementAttribute),
                  titleUIElement.stringValue(forAttribute: kAXRoleAttribute) == "AXStaticText",
                  let title = titleUIElement.stringValue(forAttribute: kAXValueAttribute),
                  !title.isEmpty {
            return title
        } else {
            return nil
        }
    }

    private static func getDescription(_ element: AXUIElement) -> String? {
        if let description = element.stringValue(forAttribute: kAXDescriptionAttribute), !description.isEmpty {
            return description
        } else {
            return nil
        }
    }

    private static func getLabel(_ element: AXUIElement) -> String? {
        if let label = element.stringValue(forAttribute: kAXLabelValueAttribute), !label.isEmpty {
            return label
        } else {
            return nil
        }
    }

    private static func getValue(_ element: AXUIElement) -> String? {
        if let value = element.stringValue(forAttribute: kAXValueAttribute), !value.isEmpty {
            return value
        } else {
            return nil
        }
    }

    private static func getDomId(_ element: AXUIElement) -> String? {
        if let domId = element.stringValue(forAttribute: "AXDOMIdentifier"), !domId.isEmpty {
            return domId
        } else {
            return nil
        }
    }
}
