//
//  MessageView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/23/23.
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
        } else if message.text.isEmpty && !message.isCurrentUser {
            Divider()
        } else {
            ChatBubble(direction: message.isCurrentUser ? .right : .left) {
                Text(message.text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(message.isCurrentUser ? .white : .primary)
                    .background(message.isCurrentUser ? Color.blue.opacity(0.8) : Color.secondary.opacity(0.2))
                    .textSelection(.enabled)
            }
        }
    }

    func attributedView(results: [ParserResult]) -> some View {
        ChatBubble(direction: .left) {
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
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(Color.secondary.opacity(0.2))
        }
    }
}

#Preview {
    MessageView(message: Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true))
}

#Preview {
    MessageView(message: Message(id: UUID(), text: "hello bot", isCurrentUser: true))
}

#Preview {
    MessageView(message: Message(id: UUID(), text: "hello user", isCurrentUser: false))
}


#Preview {
    var markdownString = """
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

    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        var parser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        return parser.parserResults(from: document)[0]
    }()

    return MessageView(message: Message(id: UUID(), text: markdownString, attributed: AttributedOutput(string: markdownString, results: [parserResult]), isCurrentUser: false))
}
