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

    let actions: [String]
    let children: [UIElement]

    var shortId: String {
        let id = String(id.uuidString.split(separator: "-")[0])
        return "\(self.role)_\(id)"
    }
}

extension UIElement {
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

        self.link = element.value(forAttribute: kAXURLAttribute) as? URL
        self.actions = element.actions()
        if let children = element.value(forAttribute: kAXChildrenAttribute) as? [AXUIElement] {
            self.children = children.compactMap { UIElement(from: $0, callback: callback) }
        } else {
            self.children = []
        }

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
        showActions: Bool = true,
        excludedActions: [String]? = nil,
        showGroups: Bool = false
    ) -> String? {
        guard showGroups || self.role != "AXGroup" else {
            var line = ""
            for child in self.children {
                if let childLine = child.serialize(
                    indent: indent,
                    isVisible: isVisible,
                    isIndexed: isIndexed,
                    showActions: showActions,
                    excludedActions: excludedActions,
                    showGroups: showGroups
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
            text = renderAXStaticText()
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
        if showActions {
            if let excludedActions = excludedActions {
                let actions = self.actions.filter { !excludedActions.contains($0) }
                if !actions.isEmpty {
                    line += ", actions: \(self.actions)"
                }
            } else {
                line += ", actions: \(self.actions)"
            }
        }

        for child in self.children {
            if let childLine = child.serialize(
                indent: indent + 1,
                isVisible: isVisible,
                isIndexed: isIndexed,
                showActions: showActions,
                excludedActions: excludedActions,
                showGroups: showGroups
            ), !childLine.isEmpty {
                line += "\n\(childLine)"
            }
        }

        return line
    }

    private func renderAXStaticText() -> String {
        return "\"\(self.value ?? "")\""
    }
}
