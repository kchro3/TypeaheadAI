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
        return UIElementVisitor.visit(element: self)
    }

    func value(forAttribute attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(self, attribute as CFString, &value)
        return value
    }

    func subelement(forAttribute attribute: String) -> AXUIElement? {
        guard let value = self.value(forAttribute: attribute) else {
            return nil
        }
        
        return (value as! AXUIElement)
    }

    func role() -> String? {
        return self.stringValue(forAttribute: kAXSubroleAttribute) ?? self.stringValue(forAttribute: kAXRoleAttribute)
    }

    func topMost() -> AXUIElement? {
        return self.subelement(forAttribute: kAXTopLevelUIElementAttribute)
    }

    func stringValue(forAttribute attribute: String) -> String? {
        guard let value = self.value(forAttribute: attribute) else {
            return nil
        }

        return value as? String
    }

    func boolValue(forAttribute attribute: String) -> Bool {
        guard let value = self.value(forAttribute: attribute) else {
            return false
        }

        return (value as? Bool) ?? false
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
        return self.subelement(forAttribute: kAXParentAttribute)
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
        guard result == .success, let element = element else {
            return nil
        }

        /// DFS until we find an element in the mouse position
        /// NOTE: Push the children to stack in reverse-order for in-order traversal.
        var stack: [AXUIElement] = []
        for child in element.children().reversed() {
            stack.append(child)
        }

        while let subElement = stack.popLast() {
            if let point = subElement.pointValue(forAttribute: kAXPositionAttribute),
               let size = subElement.sizeValue(forAttribute: kAXSizeAttribute),
               CGRect(origin: point, size: size).contains(mousePoint),
               subElement.actions().contains("AXPress") {
                // EARLY TERMINATE if AXPress-able element is found
                return subElement
            }

            // Add all children if dimensionless
            for child in subElement.children().reversed() {
                stack.append(child)
            }
        }

        return element
    }

    func getElementInFocus() -> AXUIElement? {
        return self.subelement(forAttribute: kAXFocusedUIElementAttribute)
    }

    func serialize() -> String? {
        if let uiElement = UIElementVisitor.visit(element: self),
           let serialized = uiElement.serialize() {
            return serialized
        } else {
            return nil
        }
    }

    /// NOTE: if isReflexive is true, then the condition can be true of the caller.
    func findFirst(condition: (AXUIElement) -> Bool, isReflexive: Bool = false) -> AXUIElement? {
        if isReflexive, condition(self) {
            return self
        }

        for child in self.children() {
            if let match = child.findFirst(condition: condition, isReflexive: true) {
                return match
            }
        }

        return nil
    }
}
