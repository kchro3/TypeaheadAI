//
//  AXUIElement+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

extension AXUIElement {
    func toUIElement() -> UIElement? {
        return UIElement(from: self)
    }

    func value(forAttribute attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(self, attribute as CFString, &value)
        return value
    }

    func stringValue(forAttribute attribute: String) -> String? {
        guard let value = self.value(forAttribute: attribute) else {
            return nil
        }

        return value as? String
    }

    func stringArrayValue(forAttribute attribute: String) -> [String]? {
        guard let value = self.value(forAttribute: attribute) else {
            return nil
        }

        return value as? [String]
    }

    func pointValue(forAttribute attribute: String) -> CGPoint? {
        guard let value = self.value(forAttribute: attribute) else {
            return nil
        }

        let axValue = value as! AXValue

        var point = CGPoint()
        if AXValueGetType(axValue) == .cgPoint {
            AXValueGetValue(axValue, .cgPoint, &point)
        }

        return point
    }

    func sizeValue(forAttribute attribute: String) -> CGSize? {
        guard let value = self.value(forAttribute: attribute) else {
            return nil
        }

        let axValue = value as! AXValue

        var size = CGSize()
        if AXValueGetType(axValue) == .cgSize {
            AXValueGetValue(axValue, .cgSize, &size)
        }

        return size
    }

    func parent() -> AXUIElement? {
        guard let value = self.value(forAttribute: kAXParentAttribute) else {
            return nil
        }

        return (value as! AXUIElement)
    }

    func children() -> [AXUIElement] {
        if let children = self.value(forAttribute: kAXChildrenAttribute) as? [AXUIElement] {
            return children
        } else {
            return []
        }
    }

    func attributes() -> [String] {
        var attributeNames: CFArray?
        let result = AXUIElementCopyAttributeNames(self, &attributeNames)
        guard result == .success, let attributes = attributeNames as? [String] else {
            return []
        }

        return attributes
    }

    func actions() -> [String] {
        var actionNames: CFArray?
        let result = AXUIElementCopyActionNames(self, &actionNames)

        guard result == .success, let actions = actionNames as? [String] else {
            return []
        }

        return actions
    }

    func getElementAtMousePosition(_ mousePos: NSPoint) -> AXUIElement? {
        var element: AXUIElement?

        let point = CGPoint(x: mousePos.x, y: NSHeight(NSScreen.screens[0].frame) - mousePos.y)
        let result = AXUIElementCopyElementAtPosition(self, Float(point.x), Float(point.y), &element)
        guard result == .success else {
            return nil
        }

        return element
    }

    func getMouseOverElement(_ mousePos: NSPoint) -> AXUIElement? {
        var element: AXUIElement?
        let mousePoint = CGPoint(x: mousePos.x, y: NSHeight(NSScreen.screens[0].frame) - mousePos.y)
        let result = AXUIElementCopyElementAtPosition(self, Float(mousePoint.x), Float(mousePoint.y), &element)
        guard result == .success else {
            return nil
        }
        
        /// DFS until we find an element in the mouse position
        /// NOTE: Push the children to stack in reverse-order for in-order traversal.
        var stack: [AXUIElement] = []
        if let children = element?.children() {
            for child in children.reversed() {
                stack.append(child)
            }
        }

        while let subElement = stack.popLast() {
            if let point = subElement.pointValue(forAttribute: kAXPositionAttribute),
               let size = subElement.sizeValue(forAttribute: kAXSizeAttribute),
               size.width * size.height > 1.0 {
                // Only recurse if the frame contains the mouse click
//                print(
//                    subElement.stringValue(forAttribute: kAXRoleAttribute) ?? "none",
//                    subElement.stringValue(forAttribute: kAXTitleAttribute) ?? "none",
//                    CGRect(origin: point, size: size),
//                    subElement.actions()
//                )

                if CGRect(origin: point, size: size).contains(mousePoint) {
                    // EARLY TERMINATE if AXPress-able element is found
                    guard !subElement.actions().contains("AXPress") else {
                        return subElement
                    }

                    for child in subElement.children().reversed() {
                        stack.append(child)
                    }
                }
            } else {
                // Add all children if dimensionless
                for child in subElement.children().reversed() {
                    stack.append(child)
                }
            }
        }

        return element
    }

    func getElementInFocus() -> AXUIElement? {
        guard let value = self.value(forAttribute: kAXFocusedUIElementAttribute) else {
            return nil
        }

        return (value as! AXUIElement)
    }
}
