//
//  TableView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/29/23.
//

import SwiftUI
import Markdown

struct TableView: View {
    let parserResult: ParserResult

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(NSAttributedString(parserResult.attributedString).string.components(separatedBy: "\n"), id: \.self) { row in
                HStack(spacing: 0) {
                    if row.contains("---") {
                        Divider().padding(0).frame(maxHeight: 1)
                    } else {
                        ForEach(row.components(separatedBy: "|").dropFirst().dropLast().map { $0.trimmingCharacters(in: .whitespaces) }, id: \.self) { cell in
                            Text(cell)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(5)
                                .border(Color.gray)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    let markdownString = "| Header 1 | Header 2 |\n| -------- | -------- |\n| Cell 1   | Cell 2   |"
    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        var parser = MarkdownAttributedStringParser(isDarkMode: false)
        return parser.parserResults(from: document)[0]
    }()

    return TableView(parserResult: parserResult)
}

#Preview {
    let markdownString = "| Unbalanced Header 1 | Header 2 |\n| -------- | -------- |\n| Cell 1   | Cell 2   |"
    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        var parser = MarkdownAttributedStringParser(isDarkMode: false)
        return parser.parserResults(from: document)[0]
    }()

    return TableView(parserResult: parserResult)
}
