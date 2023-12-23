//
//  String+HTMLParser.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/4/23.
//

import Foundation
import SwiftSoup

extension String {
    /// Removes attributions from all HTML tags
    func sanitizeHTML() throws -> String {
        let doc: SwiftSoup.Document = try SwiftSoup.parse(self)
        let elements: SwiftSoup.Elements = try doc.getAllElements()
        let whitelistAttributes = [
            "href"
        ]

        for element in elements {
            if let attributes = element.getAttributes() {
                for attribute in attributes {
                    if !whitelistAttributes.contains(attribute.getKey()) {
                        try element.removeAttr(attribute.getKey())
                    }
                }
            }
        }

        return try doc.html()
    }

    func extractAttributes(_ attributeToExtract: String) throws -> [String] {
        let doc: SwiftSoup.Document = try SwiftSoup.parse(self)
        let elements: SwiftSoup.Elements = try doc.getAllElements()

        var values: [String] = []
        for element in elements {
            if let attributes = element.getAttributes() {
                for attribute in attributes {
                    if attributeToExtract == attribute.getKey(),
                       let value = try? element.attr(attribute.getKey()) {
                        values.append(value)
                    }
                }
            }
        }

        return values
    }
}
