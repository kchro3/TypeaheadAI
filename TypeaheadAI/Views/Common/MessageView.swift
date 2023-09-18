//
//  MessageView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/17/23.
//

import SwiftUI
import Markdown

struct MessageView: View {
    let message: Message
    var onButtonDown: (() -> Void)?

    init(
        message: Message,
        onButtonDown: (() -> Void)? = nil
    ) {
        self.message = message
        self.onButtonDown = onButtonDown
    }

    var body: some View {
        if let error = message.responseError, !message.isCurrentUser {
            HStack {
                Text(error)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.red.opacity(0.4))
                    )

                Button(action: {
                    onButtonDown?()
                }, label: {
                    Image(systemName: "arrow.counterclockwise")
                })
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let attributed = message.attributed {
            attributedView(results: attributed.results)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: message.isCurrentUser ? .trailing : .leading)
        } else if message.text.isEmpty && !message.isCurrentUser {
            Divider()
        } else {
            Text(message.text)
                .foregroundColor(message.isCurrentUser ? .white : .primary)
                .textSelection(.enabled)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(message.isCurrentUser ? Color.blue.opacity(0.8) : Color.clear)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: message.isCurrentUser ? .trailing : .leading)
        }
    }

    func attributedView(results: [ParserResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(results) { parsed in
                if parsed.isCodeBlock {
                    CodeBlockView(parserResult: parsed)
                        .padding(.bottom, 24)
                        .textSelection(.enabled)
                } else {
                    Text(parsed.attributedString)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageView(message: Message(id: UUID(), createdAt: Date(), text: "hello", isCurrentUser: true))
            MessageView(message: Message(id: UUID(), createdAt: Date(), text: "hello", isCurrentUser: false))
            MessageView(message: Message(id: UUID(), createdAt: Date(), text: "hello", attributed: AttributedOutput(string: markdownString, results: [parserResult]), isCurrentUser: false))
        }
    }

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
}
