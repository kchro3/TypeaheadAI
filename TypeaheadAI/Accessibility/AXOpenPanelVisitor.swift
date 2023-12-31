//
//  AXOpenPanelVisitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/26/23.
//

import Foundation

/// Ideally not static, but whatever. I don't know if we'll need stateful visitors yet.
class AXOpenPanelVisitor {
    static func visit(
        element: UIElement,
        indent: Int,
        isIndexed: Bool
    ) throws -> String? {
        guard element.role == "AXSheet", element.identifier == "open-panel" else {
            return nil
        }

        let indentation = String(repeating: "  ", count: indent)
        var line: String
        if isIndexed {
            line = "\(indentation)\(element.shortId): open-panel"
        } else {
            line = "\(indentation)\(element.role): open-panel"
        }

        /// NOTE: This actually depends on the user preferences on how to render the files...
        /// Let's fix this later.
        if let listView = element.findFirst(condition: {
            $0.role == "AXOutline" && $0.identifier == "ListView"
        }) {
            for listItem in listView.findAll(condition: { $0.role == "AXTextField" && $0.link != nil }) {
                if let childLine = listItem.serialize(indent: indent + 1, isIndexed: isIndexed, maxDepth: 1) {
                    line += "\n\(childLine)"
                }
            }
        }

        return line
    }
}
