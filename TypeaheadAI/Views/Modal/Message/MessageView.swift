//
//  MessageView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/23/23.
//

import SwiftUI
import Markdown
import UniformTypeIdentifiers

struct MessageView: View {
    var message: Message
    var onEdit: ((String) -> Void)?
    var onEditAppear: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onTruncate: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    @State private var webViewHeight: CGFloat = .zero
    @State private var isMessageTruncated = true
    @State private var isEditing = false
    @State private var localContent: String = ""

    private let maxMessageLength = 280

    init(
        message: Message,
        onEdit: ((String) -> Void)? = nil,
        onEditAppear: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onTruncate: (() -> Void)? = nil
    ) {
        self.message = message
        self.onEdit = onEdit
        self.onEditAppear = onEditAppear
        self.onRefresh = onRefresh
        self.onTruncate = onTruncate
    }

    var body: some View {
        if let error = message.responseError {
            MessageFailedView(error: error, onRefresh: onRefresh)
        } else if let attributed = message.attributed,
                  isMarkdown(attributed: attributed) {
            aiMarkdown(results: attributed.results)
        } else if message.text.isEmpty && !message.isCurrentUser {
            // NOTE: This is broken...
            Divider()
        } else if message.isCurrentUser {
            userMessage
        } else {
            aiMessage
        }
    }

    @ViewBuilder
    var userMessage: some View {
        ChatBubble(
            direction: .right,
            onEdit: {
                isEditing.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    onEditAppear?()
                }
            }
        ) {
            switch message.messageType {
            case .string:
                if isEditing {
                    CustomTextField(
                        text: $localContent,
                        placeholderText: "",
                        autoCompleteSuggestions: [],
                        onEnter: { newContent in
                            isEditing = false
                            if !localContent.isEmpty {
                                onEdit?(localContent)
                            }
                        }
                    )
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(.primary)
                    .background(Color.accentColor.opacity(0.2))
                    .onAppear(perform: {
                        localContent = message.text
                    })
                } else if message.text.count > maxMessageLength {
                    // Truncatable string
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
                                    Text("See more").bold()
                                } else {
                                    Text("See less").bold()
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
                        .resizable()
                        .scaledToFit()
                        .frame(width: 512, height: 512)
                }
            case .data(let data):
                if let imageData = try? self.decodeImage(data) {
                    Image(nsImage: imageData)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 512, height: 512)
                }
            }
        }
        .padding(.leading, 100)
    }

    @ViewBuilder
    var aiMessage: some View {
        HStack {
            ChatBubble(direction: .left, onEdit: {
                isEditing.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    onEditAppear?()
                }
            }, onRefresh: onRefresh) {
                switch message.messageType {
                case .string:
                    if isEditing {
                        CustomTextField(
                            text: $localContent,
                            placeholderText: "",
                            autoCompleteSuggestions: [],
                            onEnter: { newContent in
                                isEditing = false
                                if !localContent.isEmpty {
                                    onEdit?(localContent)
                                }
                            }
                        )
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .foregroundColor(.primary)
                        .background(Color.accentColor.opacity(0.2))
                        .onAppear(perform: {
                            localContent = message.text
                        })
                    } else {
                        Text(message.text)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .foregroundColor(.primary)
                            .background(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            .textSelection(.enabled)
                    }
                case .html(let data):
                    WebView(html: data, dynamicHeight: $webViewHeight)
                        .frame(width: 400, height: webViewHeight)
                        .background(Color.accentColor.opacity(0.8))
                case .image(let data):
                    if let imageData = try? self.decodeBase64Image(data.image) {
                        Image(nsImage: imageData)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 512, height: 512)
                            .onDrag {
                                return NSItemProvider(item: data.toURL() as NSSecureCoding, typeIdentifier: UTType.fileURL.identifier)
                            }
                    }
                case .data(let data):
                    if let imageData = try? self.decodeImage(data) {
                        Image(nsImage: imageData)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 512, height: 512)
                    }
                }
            }
        }
    }

    private func messageFailed(error: String) -> some View {
        HStack {
            // Message itself (wrap in a chat?)
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
                onRefresh?()
            }, label: {
                Image(systemName: "arrow.counterclockwise")
            })
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func aiMarkdown(results: [ParserResult]) -> some View {
        ChatBubble(direction: .left, onEdit: {
            isEditing.toggle()
        }, onRefresh: onRefresh) {
            Group {
                if isEditing {
                    CustomTextField(text: $localContent, placeholderText: "", autoCompleteSuggestions: [], onEnter: { newContent in
                        isEditing = false
                        if !localContent.isEmpty {
                            onEdit?(localContent)
                        }
                    })
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(.primary)
                    .background(Color.accentColor.opacity(0.4))
                    .onAppear(perform: {
                        localContent = message.text
                        onEditAppear?()
                    })
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(results) { parsed in
                            if case .codeBlock(_) = parsed.parsedType {
                                CodeBlockView(parserResult: parsed)
                                    .padding(.bottom, 24)
                            } else if case .table = parsed.parsedType {
                                MarkdownTableView(parserResult: parsed)
                                    .textSelection(.enabled)
                            } else {
                                Text(parsed.attributedString)
                                    .textSelection(.enabled)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.secondary.opacity(0.15))
        }
    }

    /// This is simply a heuristic.
    private func isMarkdown(attributed: AttributedOutput) -> Bool {
        if attributed.results.count == 0 {
            // If no text, then not Markdown
            return false
        } else if attributed.results.count > 1 {
            return true
        } else if attributed.results[0].parsedType != .plaintext {
            return true
        } else {
            // Check for artifacts of markdown
            return attributed.string.contains("##") || attributed.string.contains("**") ||
                attributed.string.contains("[//]: #") ||
                attributed.string.contains("`") ||
                attributed.string.contains("](")
        }
    }

    private func decodeImage(_ data: Data) throws -> NSImage? {
        guard let image = NSImage(data: data) else {
            return nil
        }

        return image
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
