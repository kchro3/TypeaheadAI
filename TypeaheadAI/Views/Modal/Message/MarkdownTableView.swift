//
//  GenericTableView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/5/23.
//

import SwiftUI
import Markdown

struct TableCell: Identifiable, Hashable {
    var id: String
}

struct GenericTableView: View {
    let header: [TableCell]
    let data: [[TableCell]]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                ForEach(header, id: \.id) { cell in
                    Text(cell.id)
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(4)
            .foregroundStyle(Color.white)
            .background(Color.secondary.opacity(0.4))
            .font(.headline)

            // Data
            ForEach(data, id: \.self) { row in
                Divider()
                HStack {
                    ForEach(row, id: \.id) { cell in
                        Text(cell.id)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(5)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? HighlighterConstants.dark.opacity(0.4) : HighlighterConstants.light.opacity(0.4))
        )
        .cornerRadius(8)
    }
}

struct MarkdownTableView: View {
    var header: [TableCell]
    var data: [[TableCell]]

    @Environment(\.colorScheme) private var colorScheme

    init(parserResult: ParserResult) {
        let rows = NSAttributedString(parserResult.attributedString).string.components(separatedBy: "\n")

        header = []
        data = []
        for index in rows.indices {
            guard !rows[index].isEmpty else {
                continue
            }

            let cols = rows[index].components(separatedBy: "\t").map {
                TableCell(id: $0.trimmingCharacters(in: .whitespaces))
            }

            if index == 0 {
                header = cols
            } else {
                data.append(cols)
            }
        }
    }

    var body: some View {
        GenericTableView(header: header, data: data)
    }
}

#Preview {
    let markdownString = "| Unbalanced Header 1 | Header 2 |\n| -------- | -------- |\n| Cell 1   | Cell 2   |"
    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        var parser = MarkdownAttributedStringParser(isDarkMode: false)
        return parser.parserResults(from: document)[0]
    }()

    return MarkdownTableView(parserResult: parserResult)
}


#Preview {
    let markdownString = "| Unbalanced Header 1 | Header 2 |\n| -------- | -------- |\n| Pretty long content in Cell Number 1 Pretty long content in Cell Number 1 Pretty long content in Cell Number 1    | Cell 2   |\n| Cell 1   | Cell 2   |"
    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        var parser = MarkdownAttributedStringParser(isDarkMode: false)
        return parser.parserResults(from: document)[0]
    }()

    return MarkdownTableView(parserResult: parserResult)
}
