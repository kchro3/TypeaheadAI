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
        guard let role = self.stringValue(forAttribute: kAXRoleAttribute) else {
            return nil
        }

        return UIElement(
            id: 0,
            role: role,
            title: self.getTitle(),
            description: self.getDescription(),
            label: self.getLabel(),
            value: self.getValue(),
            link: self.value(forAttribute: kAXURLAttribute) as? URL,
            point: self.pointValue(forAttribute: kAXPositionAttribute),
            size: self.sizeValue(forAttribute: kAXSizeAttribute),
            domId: self.getDomId(),
            domClasses: nil,
            enabled: self.boolValue(forAttribute: kAXEnabledAttribute),
            identifier: self.stringValue(forAttribute: kAXIdentifierAttribute),
            actions: self.actions(),
            parentRole: self.parent()?.stringValue(forAttribute: kAXRoleAttribute),
            attributes: self.attributes()
        )
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

    func children(maxChildren: Int? = nil) -> [AXUIElement] {
        if let children = self.value(forAttribute: kAXChildrenAttribute) as? [AXUIElement] {
            if let maxChildren = maxChildren, children.count > maxChildren {
                return Array(children.prefix(maxChildren))
            } else {
                return children
            }
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

    func getCenter() -> CGPoint? {
        guard let size = self.sizeValue(forAttribute: kAXSizeAttribute),
              let point = self.pointValue(forAttribute: kAXPositionAttribute),
              size.width * size.height > 1.0 else {
            return nil
        }

        return CGPoint(
            x: point.x + size.width / 2,
            y: point.y + size.height / 2
        )
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
        if let focusedElement = self.subelement(forAttribute: kAXFocusedUIElementAttribute) {
            return focusedElement.getElementInFocus() ?? focusedElement
        } else {
        }

        return nil
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

    private func getTitle() -> String? {
        if let title = self.stringValue(forAttribute: kAXTitleAttribute), !title.isEmpty {
            return title
        } else if let titleUIElement = self.subelement(forAttribute: kAXTitleUIElementAttribute),
                  titleUIElement.stringValue(forAttribute: kAXRoleAttribute) == "AXStaticText",
                  let title = titleUIElement.stringValue(forAttribute: kAXValueAttribute),
                  !title.isEmpty {
            return title
        } else {
            return nil
        }
    }

    private func getDescription() -> String? {
        if let description = self.stringValue(forAttribute: kAXDescriptionAttribute), !description.isEmpty {
            return description
        } else {
            return nil
        }
    }

    private func getLabel() -> String? {
        if let label = self.stringValue(forAttribute: kAXLabelValueAttribute), !label.isEmpty {
            return label
        } else {
            return nil
        }
    }

    private func getValue() -> String? {
        if let value = self.stringValue(forAttribute: kAXValueAttribute), !value.isEmpty {
            return value
        } else {
            return nil
        }
    }

    private func getDomId() -> String? {
        if let domId = self.stringValue(forAttribute: "AXDOMIdentifier"), !domId.isEmpty {
            return domId
        } else {
            return nil
        }
    }
}
