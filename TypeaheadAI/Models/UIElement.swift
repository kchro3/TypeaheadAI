//
//  UIElement.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import AppKit
import Foundation

struct UIElement: Identifiable, Codable, Equatable {
    let id: UUID
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

    let actions: [String]
    let parentRole: String?
    let children: [UIElement]
    let attributes: [String]

    var shortId: String {
        let id = String(id.uuidString.split(separator: "-")[0])
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
            && self.attributes == other.attributes
        )
    }
}

extension UIElement {
    private static let maxChildren = 25
    private static let maxCharacterCount = 4000
    private static let defaultExcludedRoles = ["AXGroup", "AXImage"]

    init?(from element: AXUIElement, callback: ((String, AXUIElement) -> Void)? = nil) {
        guard let role = element.stringValue(forAttribute: kAXRoleAttribute) else {
            return nil
        }

        self.id = UUID()
        self.role = role
        self.point = element.pointValue(forAttribute: kAXPositionAttribute)
        self.size = element.sizeValue(forAttribute: kAXSizeAttribute)

        if let titleAttr = element.stringValue(forAttribute: kAXTitleAttribute), !titleAttr.isEmpty {
            self.title = titleAttr
        } else {
            self.title = nil
        }

        if let descAttr = element.stringValue(forAttribute: kAXDescriptionAttribute), !descAttr.isEmpty {
            self.description = descAttr
        } else {
            self.description = nil
        }

        if let valueAttr = element.stringValue(forAttribute: kAXValueAttribute), !valueAttr.isEmpty {
            self.value = valueAttr
        } else {
            self.value = nil
        }

        if let labelAttr = element.stringValue(forAttribute: kAXLabelValueAttribute), !labelAttr.isEmpty {
            self.label = labelAttr
        } else {
            self.label = nil
        }

        if let domAttr = element.stringValue(forAttribute: "AXDOMIdentifier"), !domAttr.isEmpty {
            self.domId = domAttr
        } else {
            self.domId = nil
        }

//        if let domClassesAttr = element.stringArrayValue(forAttribute: "AXDOMClassList"), !domClassesAttr.isEmpty {
//            self.domClasses = domClassesAttr
//        } else {
        self.domClasses = nil
//        }

        self.link = element.value(forAttribute: kAXURLAttribute) as? URL
        self.actions = element.actions()

        self.parentRole = element.parent()?.stringValue(forAttribute: kAXRoleAttribute)
        if let children = element.value(forAttribute: kAXChildrenAttribute) as? [AXUIElement] {
            self.children = children.compactMap { UIElement(from: $0, callback: callback) }
        } else {
            self.children = []
        }

        self.attributes = element.attributes()

        // NOTE: The caller can maintain state
        callback?(self.shortId, element)
    }

    /// Convert to string representation
    /// isVisible: Only print visible UIElements
    /// isIndexed: Don't print indices
    func serialize(
        indent: Int = 0,
        isVisible: Bool = true,
        isIndexed: Bool = true,
        showActions: Bool = false,
        excludedRoles: [String]? = UIElement.defaultExcludedRoles,
        excludedActions: [String]? = nil,
        maxDepth: Int? = nil
    ) -> String? {
        if let maxDepth = maxDepth, maxDepth == indent {
            // If the indent reaches the maxDepth, terminate.
            // If maxDepth is nil, then it recurses exhaustively.
            return nil
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
        var text: String = "none"
        if role == "AXStaticText" {
            return renderAXStaticText()
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
                text += ", value: \(value)"
            }
            if let domId = self.domId {
                text += ", domId: \(domId)"
            }
            if let domClasses = self.domClasses {
                text += ", domClasses: \(domClasses)"
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

        var actions: [String] = self.actions
        if let excludedActions = excludedActions {
            actions = self.actions.filter { !excludedActions.contains($0) }
        }

        if showActions {
            if !actions.isEmpty {
                line += ", actions: \(actions)"
            }
        } else {
            if !actions.isEmpty {
                line += ", actionable: true"
            }
        }

//        line += ", attributes: \(self.attributes)"

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
}
