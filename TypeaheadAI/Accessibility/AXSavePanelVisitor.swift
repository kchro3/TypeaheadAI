//
//  AXSavePanelVisitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/27/23.
//

import Foundation

/// Ideally not static, but whatever. I don't know if we'll need stateful visitors yet.
class AXSavePanelVisitor {
    static func visit(
        tree: UIElementTree,
        element: UIElement,
        indent: Int,
        isIndexed: Bool
    ) throws -> String? {
        guard element.role == "AXSheet", element.identifier == "save-panel" else {
            return nil
        }

        let indentation = String(repeating: "  ", count: indent)
        var line: String
        if isIndexed {
            line = "\(indentation)\(element.shortId): save-panel"
        } else {
            line = "\(indentation)\(element.role): save-panel"
        }

        /// NOTE: This actually depends on the user preferences on how to render the Finder window...
        /// Let's fix this later.
        if let listView = element.findFirst(tree: tree, condition: {
            $0.role == "AXOutline" && $0.identifier == "ListView"
        }) {
            for listItem in listView.findAll(tree: tree, condition: { $0.role == "AXTextField" && $0.link != nil }) {
                if let childLine = listItem.serialize(isIndexed: isIndexed) {
                    line += "\n\(childLine)"
                }
            }
        }

        return line
    }
}
