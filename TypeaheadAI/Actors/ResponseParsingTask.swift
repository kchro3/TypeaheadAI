//
//  ResponseParsingTask.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/12/23.
//  Copied from https://github.com/alfianlosari/ChatGPTSwiftUI/blob/main/Shared/ResponseParsingTask.swift
//

import Foundation
import Markdown

actor ResponseParsingTask {
    func parse(text: String, isDarkMode: Bool) async -> AttributedOutput {
        let document = Document(parsing: text)
        var markdownParser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        let results = markdownParser.parserResults(from: document)
        return AttributedOutput(string: text, results: results)
    }
}
