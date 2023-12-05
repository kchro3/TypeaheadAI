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

        for element in elements {
            if let attributes = element.getAttributes() {
                for attribute in attributes {
                    try element.removeAttr(attribute.getKey())
                }
            }
        }

        return try doc.html()
    }
}
