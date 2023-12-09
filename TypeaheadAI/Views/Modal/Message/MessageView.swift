//
//  MessageView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/23/23.
//

import SwiftUI
import MarkdownUI
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
    private let isMarkdown: Bool

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

        if !message.isCurrentUser {
            // Just a heuristic
            self.isMarkdown = (
                message.text.contains("#") ||
                message.text.contains("](") ||
                message.text.contains("*") ||
                message.text.contains("__") ||
                message.text.contains("---") ||
                message.text.contains("[//]: #") ||
                message.text.contains("`") ||
                message.text.contains("- ") ||
                message.text.contains("1.")
            )
        } else {
            // Never render user text as markdown
            self.isMarkdown = false
        }
    }

    var body: some View {
        if let error = message.responseError {
            messageFailed(error: error)
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
            onEdit: (onEditAppear != nil) ? {
                isEditing.toggle()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    onEditAppear?()
                }
            } : nil
        ) {
            switch message.messageType {
            case .string, .function_call, .tool_call:
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
            case .markdown(let data):
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
                            Markdown(data)
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
            ChatBubble(
                direction: .left,
                onEdit: (onEditAppear != nil) ? {
                    isEditing.toggle()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        onEditAppear?()
                    }
                } : nil,
                onRefresh: onRefresh) {
                switch message.messageType {
                case .string, .markdown, .function_call, .tool_call:
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
                    } else if isMarkdown {
                        Markdown(message.text)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .foregroundColor(.primary)
                            .background(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                            .textSelection(.enabled)
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

    /// Errors can only happen on the AI side.
    private func messageFailed(error: String) -> some View {
        HStack {
            ChatBubble(
                direction: .left,
                onRefresh: onRefresh
            ) {
                Text(error)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(.primary)
                    .background(Color.red.opacity(0.4))
                    .textSelection(.enabled)
            }
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
    MessageView(message: Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "", isCurrentUser: false, isHidden: false, appContext: nil, responseError: "Something has gone horribly wrong."))
}

#Preview {
    MessageView(message: Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false, appContext: nil))
}

#Preview {
    MessageView(message: Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot", isCurrentUser: true, isHidden: false, appContext: nil))
}

#Preview {
    MessageView(message: Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello user", isCurrentUser: false, isHidden: false, appContext: nil))
}

#Preview {
    let markdownString = """
Here's an implementation of a **thing** [link](https://typeahead.ai)

Here's an `inline code`

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

    return MessageView(message: Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: markdownString, isCurrentUser: false, isHidden: false, appContext: nil))
}

#Preview {
    let markdownString = """
Dear Cynthia,

Thanks for trying out the app, really appreciate your candidness in the interviews.

Jeff
"""

    return MessageView(message: Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: markdownString, isCurrentUser: false, isHidden: false, appContext: nil))
}
