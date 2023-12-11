//
//  AXUIElement+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

extension AXUIElement {
    func value(forAttribute attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(self, attribute as CFString, &value)
        return value
    }

    func stringValue(forAttribute attribute: String) -> String? {
        guard let value = self.value(forAttribute: kAXPositionAttribute) else {
            return nil
        }

        return value as? String
    }

    func pointValue(forAttribute attribute: String) -> CGPoint? {
        guard let value = self.value(forAttribute: kAXPositionAttribute) else {
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
        guard let value = self.value(forAttribute: kAXSizeAttribute) else {
            return nil
        }

        let axValue = value as! AXValue

        var size = CGSize()
        if AXValueGetType(axValue) == .cgSize {
            AXValueGetValue(axValue, .cgSize, &size)
        }

        return size
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
}
