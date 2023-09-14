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
                .background(.secondary.opacity(0.8))

            ScrollView(.horizontal, showsIndicators: true) {
                Text(parserResult.attributedString)
                    .padding(.horizontal, 16)
                    .textSelection(.enabled)
            }
        }
        .background {
            if NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                HighlighterConstants.dark
            } else {
                HighlighterConstants.light
            }
        }
        .cornerRadius(8)
    }

    var header: some View {
        HStack {
            if let codeBlockLanguage = parserResult.codeBlockLanguage {
                Text(codeBlockLanguage.capitalized)
                    .font(.headline.monospaced())
                    .foregroundColor(.white)
            }
            Spacer()
            button
        }
    }

    @ViewBuilder
    var button: some View {
        if isCopied {
            HStack {
                Text("Copied")
                    .foregroundColor(.white)
                    .font(.subheadline.monospaced().bold())
                Image(systemName: "checkmark.circle")
                    .imageScale(.large)
                    .symbolRenderingMode(.multicolor)
            }
            .frame(alignment: .trailing)
        } else {
            Button {
                NSPasteboard.general.setString(NSAttributedString(parserResult.attributedString).string, forType: .string)

                // TODO: implement this properly. Right now, if this is
                // uncommented, the text won't actually copy.
//                withAnimation {
//                    isCopied = true
//                }
//                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
//                    withAnimation {
//                        isCopied = false
//                    }
//                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
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

    static let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)

        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)

        var parser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        return parser.parserResults(from: document)[0]
    }()

    static var previews: some View {
        CodeBlockView(parserResult: parserResult)
    }
}
