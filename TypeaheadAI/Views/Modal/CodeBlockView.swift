//
//  CodeBlockView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/12/23.
//  Copied from https://github.com/alfianlosari/ChatGPTSwiftUI/blob/main/Shared/CodeBlockView.swift
//

import SwiftUI
import Markdown

enum HighlighterConstants {
    static let color = Color(red: 25/255, green: 38/255, blue: 38/255)

    static let dark = Color(red: 34/255, green: 39/255, blue: 49/255)
    static let darkTheme = "nord"

    static let light = Color.white
    static let lightTheme = "xcode"
}

struct ParserResult: Codable, Identifiable, Equatable {
    let id: UUID
    let attributedString: AttributedString
    let isCodeBlock: Bool
    let codeBlockLanguage: String?
}

struct CodeBlockView: View {

    let parserResult: ParserResult
    @State var isCopied = false

    var body: some View {
        VStack(alignment: .leading) {
            header
                .padding(.horizontal)
                .padding(.vertical, 4)
                .background(.secondary.opacity(0.2))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(parserResult.attributedString)
                    .padding(.horizontal, 16)
                    .textSelection(.enabled)
            }
        }
        .background {
            if NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                HighlighterConstants.dark.opacity(0.2)
            } else {
                HighlighterConstants.light.opacity(0.2)
            }
        }
        .cornerRadius(8)
    }

    var header: some View {
        HStack {
            if let codeBlockLanguage = parserResult.codeBlockLanguage {
                Text(codeBlockLanguage.capitalized)
                    .font(.headline)
                    .foregroundColor(.white)
            }
            Spacer()
            button
        }
    }

    @ViewBuilder
    var button: some View {
        if isCopied {
            Image(systemName: "checkmark.circle")
                .imageScale(.large)
                .symbolRenderingMode(.multicolor)
        } else {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.prepareForNewContents()
                pasteboard.setString(NSAttributedString(parserResult.attributedString).string, forType: .string)

                withAnimation {
                    isCopied = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
    }
}

struct CodeBlockView_Previews: PreviewProvider {

    static var markdownString = """
    ```swift
    let api = ChatGPTAPI(apiKey: "API_KEY")

    Task {
        do {
            let stream = try await api.sendMessageStream(text: "What is ChatGPT?")
            for try await line in stream {
                print(line)
            }
        } catch {
            print(error.localizedDescription)
        }
    }
    ```
    """

    static let lightParserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        var parser = MarkdownAttributedStringParser(isDarkMode: false)
        return parser.parserResults(from: document)[0]
    }()

    static let darkParserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        var parser = MarkdownAttributedStringParser(isDarkMode: true)
        return parser.parserResults(from: document)[0]
    }()

    static var previews: some View {
        Group {
            CodeBlockView(parserResult: lightParserResult)
            CodeBlockView(parserResult: darkParserResult)
        }
    }
}
