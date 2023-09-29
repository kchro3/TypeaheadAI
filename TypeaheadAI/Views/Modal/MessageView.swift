//
//  MessageView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/23/23.
//

import SwiftUI
import Markdown
import WebKit

struct WebView: NSViewRepresentable {
    var html: String
    @Binding var dynamicHeight: CGFloat

    func makeNSView(context: Context) -> WKWebView  {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(html, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { (height, error) in
                if let height = height as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.dynamicHeight = height
                    }
                }
            }
        }
    }
}

struct MessageView: View {
    let message: Message
    var onButtonDown: (() -> Void)?
    @State private var webViewHeight: CGFloat = .zero

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
        } else if message.isCurrentUser {
            ChatBubble(direction: .right) {
                switch message.messageType {
                case .string:
                    Text(message.text)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.8))
                        .textSelection(.enabled)
                case .html(let data):
                    WebView(html: data, dynamicHeight: $webViewHeight)
                        .frame(width: 400, height: webViewHeight)
                        .background(Color.blue.opacity(0.8))
                }
            }
            .padding(.leading, 100)
        } else {
            ChatBubble(direction: .left) {
                Text(message.text)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(.primary)
                    .background(Color.secondary.opacity(0.2))
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

| table | of | test |
| 1     | 2  | 3    |
"""

    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        var parser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        return parser.parserResults(from: document)[0]
    }()

    return MessageView(message: Message(id: UUID(), text: markdownString, attributed: AttributedOutput(string: markdownString, results: [parserResult]), isCurrentUser: false))
}
