//
//  UIElement.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

// Wrapper class that manages uiElements and how they relate to each other
struct UIElementTree {
    let uiElements: [String : UIElement]
    let root: UIElement
    let hierarchy: [String : [String]]

    func getChildren(_ uiElement: UIElement) -> [UIElement] {
        guard let children = hierarchy[uiElement.shortId] else {
            return []
        }

        return children.compactMap { uiElements[$0] }
    }
}

struct UIElement: Identifiable, Equatable {
    let id: Int
    let role: String
    let title: String?
    let description: String?
    let label: String?
    let value: String?
    let link: URL?
    let point: CGPoint?
    let size: CGSize?
    let domId: String?
    let domClasses: [String]?
    let enabled: Bool
    let identifier: String?

    let actions: [String]
    let parentRole: String?
    let attributes: [String]

    var shortId: String {
        return "\(self.role)\(id)"
    }

    /// NOTE: This is not a true == because it ignores the ID & value
    /// We ignore the value so that two text areas can match, even if their values are different
    func equals(_ other: UIElement) -> Bool {
        return (
            self.role == other.role
            && self.title == other.title
            && self.description == other.description
            && self.label == other.label
            && self.link == other.link
            && self.point == other.point
            && self.size == other.size
            && self.domId == other.domId
            && self.domClasses == other.domClasses
            && self.parentRole == other.parentRole
            && self.identifier == other.identifier
            && self.attributes == other.attributes
        )
    }
}

extension UIElementTree {
    /// Implement iteratively with DFS
    func serialize() -> String? {
        var serialized: String? = nil
        var stack: [(Int, UIElement)] = [(0, root)]  // (Indent, UIElement)

        while let (indent, element) = stack.popLast() {
            guard let serializedElement = element.serialize() else {
                continue
            }

            if serialized == nil {
                serialized = serializedElement
            } else {
                // Add a new line, an indentation, and the serialized element
                serialized?.append("\n\(String(repeating: "  ", count: indent))\(serializedElement)")
            }

            for child in self.getChildren(element).reversed() {
                stack.append((indent + 1, child))
            }
        }

        return serialized
    }
}

extension UIElement {
    private static let maxCharacterCount = 4000
    private static let defaultExcludedRoles: [String] = ["AXGroup"]
    private static let defaultExcludedActions: [String] = ["AXShowMenu", "AXScrollToVisible", "AXCancel", "AXRaise"]

    func serialize(
        isIndexed: Bool = true,
        isVisible: Bool = true,
        showActions: Bool = false,
        excludedActions: [String]? = UIElement.defaultExcludedActions
    ) -> String? {
        var text: String
        if isIndexed {
            text = "\(self.shortId): "
        } else {
            text = ""
        }

        if role == "AXStaticText" {
            text += self.value ?? ""
        } else if role == "AXLink", let link = self.link, link.absoluteString != "about:blank" {
            if let value = self.value {
                text += "\(value), link: \(link.absoluteString)"
            } else {
                text += link.absoluteString
            }
        } else {
            text += self.title ?? ""
            if let desc = self.description {
                if text == "" {
                    text = desc
                } else {
                    text += " (\(desc))"
                }
            }
            if let label = self.label {
                text += ", label: \(label)"
            }

            if let value = self.value {
                text += ", value: \(value)"
            }

            if let domId = self.domId {
                text += ", domId: \(domId)"
            }
            if let domClasses = self.domClasses {
                text += ", domClasses: \(domClasses)"
            }
            if let link = self.link, link.absoluteString != "about:blank" {
                text += ", link: \(link.absoluteString)"
            }
        }

        /// Add actions
        var actions: [String] = self.actions
        if let excludedActions = excludedActions {
            actions = self.actions.filter { !excludedActions.contains($0) }
        }

        if showActions {
            if !actions.isEmpty, self.enabled {
                text += ", actions: \(actions)"
            }
        } else {
            if !actions.isEmpty, self.enabled {
                text += ", actionable: true"
            }
        }

        if isVisible {
            if let width = self.size?.width,
               let height = self.size?.height,
               width + height <= 1.0 {
                return nil
            }
        } else {
            if let width = self.size?.width,
               let height = self.size?.height {
                text += ", size: (\(width), \(height))"
            }
        }

        return text
    }

    private func renderAXStaticText() -> String {
        if let text = self.value {
            if text.count > UIElement.maxCharacterCount {
                let truncated = String(text.prefix(UIElement.maxCharacterCount))
                return "\(truncated)..."
            } else {
                return text
            }
        } else {
            return ""
        }
    }

    /// NOTE: if isReflexive is true, then the conditiion can be true of the caller.
    func findFirst(tree: UIElementTree, condition: (UIElement) -> Bool, isReflexive: Bool = false) -> UIElement? {
        if isReflexive, condition(self) {
            return self
        }

        for child in tree.getChildren(self) {
            if let match = child.findFirst(tree: tree, condition: condition, isReflexive: true) {
                return match
            }
        }

        return nil
    }

    /// NOTE: if isReflexive is true, then the conditiion can be true of the caller.
    func findAll(tree: UIElementTree, condition: (UIElement) -> Bool, isReflexive: Bool = false) -> [UIElement] {
        var matches: [UIElement] = []

        var stack: [UIElement]
        if isReflexive {
            stack = [self]
        } else {
            stack = tree.getChildren(self)
        }

        while let next = stack.popLast() {
            if condition(next) {
                matches.append(next)
            } else {
                for child in tree.getChildren(next) {
                    stack.append(child)
                }
            }
        }

        return matches
    }
}
