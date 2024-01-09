//
//  UIElement.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

struct UIElement: Identifiable, Codable, Equatable {
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
    let children: [UIElement]
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

extension UIElement {
    private static let maxChildren = 50
    private static let maxCharacterCount = 4000
    private static let defaultExcludedRoles: [String] = ["AXGroup"]
    private static let defaultExcludedActions: [String] = ["AXShowMenu", "AXScrollToVisible", "AXCancel", "AXRaise"]

    /// Convert to string representation
    /// isVisible: Only print visible UIElements
    /// isIndexed: Don't print indices
    ///
    /// Reimplement this as a Visitor pattern
    func serialize(
        indent: Int = 0,
        isVisible: Bool = true,
        isIndexed: Bool = true,
        showActions: Bool = false,
        excludedRoles: [String]? = UIElement.defaultExcludedRoles,
        excludedActions: [String]? = UIElement.defaultExcludedActions,
        maxDepth: Int? = nil
    ) -> String? {
        if let maxDepth = maxDepth, maxDepth == indent {
            // If the indent reaches the maxDepth, terminate.
            // If maxDepth is nil, then it recurses exhaustively.
            return nil
        }

        if let serializedOpenPanel = try? AXOpenPanelVisitor.visit(element: self, indent: indent, isIndexed: isIndexed) {
            return serializedOpenPanel
        }

        if let serializedSavePanel = try? AXSavePanelVisitor.visit(element: self, indent: indent, isIndexed: isIndexed) {
            return serializedSavePanel
        }

        if (excludedRoles ?? []).contains(self.role) {
            // Ignore excluded roles
            var line = ""
            for child in self.children.prefix(UIElement.maxChildren) {
                if let childLine = child.serialize(
                    indent: indent,
                    isVisible: isVisible,
                    isIndexed: isIndexed,
                    showActions: showActions,
                    excludedRoles: excludedRoles,
                    excludedActions: excludedActions,
                    maxDepth: maxDepth
                ), !childLine.isEmpty {
                    if line.isEmpty {
                        line = childLine
                    } else {
                        line += "\n\(childLine)"
                    }
                }
            }
            return line
        }

        let indentation = String(repeating: "  ", count: indent)

        // NOTE: This is to help the LLM parse the UIElement tree. This will get complicated fast.
        //
        // If title & description exist: <title> (<desc>)
        // If title doesn't exist:       <desc>
        // If description doesn't exist: <title>
        // If neither exist:             none
        var text: String

        if role == "AXStaticText" {
            text = self.value ?? "none"
        } else {
            text = self.title ?? "none"
            if let desc = self.description {
                if text == "none" {
                    text = desc
                } else {
                    text += " (\(desc))"
                }
            }
            if let label = self.label {
                text += ", label: \(label)"
            }

            if let value = self.value {
                let escapedNewlines = value.replacingOccurrences(of: "\n", with: "\\n")
                text += ", value: \(escapedNewlines)"
            }
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

        var line = ""
        if isIndexed {
            line += "\(indentation)\(self.shortId): \(text)"
        } else {
            line += "\(indentation)\(self.role): \(text)"
        }

        if self.role == "AXCell" {
            for (index, child) in self.children.prefix(UIElement.maxChildren).enumerated() {
                if index > 0, self.children[index-1].role == "AXStaticText", self.children[index].role == "AXStaticText" {
                    // If there are consecutive children with the role AXStaticText, just keep appending to the line
                    line += child.renderAXStaticText()
                } else if let childLine = child.serialize(
                    indent: indent + 1,
                    isVisible: isVisible,
                    isIndexed: isIndexed,
                    showActions: showActions,
                    excludedRoles: excludedRoles,
                    excludedActions: excludedActions,
                    maxDepth: maxDepth
                ), !childLine.isEmpty {
                    line += "\n\(childLine)"
                }
            }
        } else if self.role == "AXStaticText" {
            return line
        } else {
            for child in self.children.prefix(UIElement.maxChildren) {
                if let childLine = child.serialize(
                    indent: indent + 1,
                    isVisible: isVisible,
                    isIndexed: isIndexed,
                    showActions: showActions,
                    excludedRoles: excludedRoles,
                    excludedActions: excludedActions,
                    maxDepth: maxDepth
                ), !childLine.isEmpty {
                    line += "\n\(childLine)"
                }
            }
        }

        return line
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
    func findFirst(condition: (UIElement) -> Bool, isReflexive: Bool = false) -> UIElement? {
        if isReflexive, condition(self) {
            return self
        }

        for child in self.children {
            if let match = child.findFirst(condition: condition, isReflexive: true) {
                return match
            }
        }

        return nil
    }

    /// NOTE: if isReflexive is true, then the conditiion can be true of the caller.
    func findAll(condition: (UIElement) -> Bool, isReflexive: Bool = false) -> [UIElement] {
        var matches: [UIElement] = []

        var stack: [UIElement]
        if isReflexive {
            stack = [self]
        } else {
            stack = self.children
        }

        while let next = stack.popLast() {
            if condition(next) {
                matches.append(next)
            } else {
                for child in next.children {
                    stack.append(child)
                }
            }
        }

        return matches
    }
}
