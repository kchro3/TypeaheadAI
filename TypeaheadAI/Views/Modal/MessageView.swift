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
    var message: Message
    var onButtonDown: (() -> Void)?
    var onTruncate: (() -> Void)?

    @State private var webViewHeight: CGFloat = .zero
    @State private var isMessageTruncated = true

    private let maxMessageLength = 280

    init(
        message: Message,
        onButtonDown: (() -> Void)? = nil,
        onTruncate: (() -> Void)? = nil
    ) {
        self.message = message
        self.onButtonDown = onButtonDown
        self.onTruncate = onTruncate
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
                    if message.text.count > maxMessageLength {
                        VStack {
                            if message.isTruncated {
                                Text(message.text.prefix(maxMessageLength))
                            } else {
                                Text(message.text)
                            }
                            HStack {
                                Spacer()
                                Button(action: {
                                    onTruncate?()
                                }, label: {
                                    if message.isTruncated {
                                        Text("See more")
                                    } else {
                                        Text("See less")
                                    }
                                })
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .foregroundColor(.white)
                        .background(Color.accentColor.opacity(0.8))
                        .textSelection(.enabled)
                    } else {
                        Text(message.text)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .foregroundColor(.white)
                            .background(Color.accentColor.opacity(0.8))
                            .textSelection(.enabled)
                    }
                case .html(let data):
                    WebView(html: data, dynamicHeight: $webViewHeight)
                        .frame(width: 400, height: webViewHeight)
                        .background(Color.accentColor.opacity(0.8))
                case .image(let data):
                    if let imageData = try? self.decodeBase64Image(data.image) {
                        Image(nsImage: imageData)
                    }
                }
            }
            .padding(.leading, 100)
        } else {
            ChatBubble(direction: .left) {
                switch message.messageType {
                case .string:
                    Text(message.text)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .foregroundColor(.primary)
                        .background(Color.secondary.opacity(0.2))
                        .textSelection(.enabled)
                case .html(let data):
                    WebView(html: data, dynamicHeight: $webViewHeight)
                        .frame(width: 400, height: webViewHeight)
                        .background(Color.accentColor.opacity(0.8))
                case .image(let data):
                    if let imageData = try? self.decodeBase64Image(data.image) {
                        Image(nsImage: imageData)
                    }
                }
            }
        }
    }

    func attributedView(results: [ParserResult]) -> some View {
        ChatBubble(direction: .left) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(results) { parsed in
                    if case .codeBlock(_) = parsed.parsedType {
                        CodeBlockView(parserResult: parsed)
                            .padding(.bottom, 24)
                    } else if case .table = parsed.parsedType {
                        TableView(parserResult: parsed)
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

    private func decodeBase64Image(_ b64Data: String) throws -> NSImage? {
        guard let data = Data(base64Encoded: b64Data) else {
            return nil
        }

        guard let image = NSImage(data: data) else {
            return nil
        }

        return image
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
    let markdownString = """
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

| table | of  | test |
| ----- | --- | ---- |
| 1     | 2   | 3    |
"""

    let parserResults: [ParserResult] = {
        let document = Document(parsing: markdownString)
        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        var parser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        return parser.parserResults(from: document)
    }()

    return MessageView(message: Message(id: UUID(), text: markdownString, attributed: AttributedOutput(string: markdownString, results: parserResults), isCurrentUser: false))
}
