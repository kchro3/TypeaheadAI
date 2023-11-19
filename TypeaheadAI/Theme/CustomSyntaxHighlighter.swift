//
//  CustomSyntaxHighlighter.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/19/23.
//

import Foundation
import Highlighter
import MarkdownUI
import SwiftUI

enum HighlighterConstants {
    static let color = Color(red: 25/255, green: 38/255, blue: 38/255)

    static let dark = Color(red: 34/255, green: 39/255, blue: 49/255)
    static let darkTheme = "nord"

    static let light = Color.white
    static let lightTheme = "xcode"
}

struct CustomSyntaxHighlighter: CodeSyntaxHighlighter {
    var highlighter: Highlighter = Highlighter()!

    init(theme: String) {
        highlighter.setTheme(theme)
    }

    func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlighted = highlighter.highlight(code, as: language) else {
            return Text(code)
        }

        return Text(AttributedString(highlighted))
    }
}

extension CodeSyntaxHighlighter where Self == CustomSyntaxHighlighter {
    static func custom(theme: String) -> Self {
        CustomSyntaxHighlighter(theme: theme)
    }
}
