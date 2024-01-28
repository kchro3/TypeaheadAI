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
    var onConfigure: (() -> Void)?
    var onEdit: ((String) -> Void)?
    var onEditAppear: (() -> Void)?
    var onRefresh: (() -> Void)?
    var onTruncate: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    @State private var webViewHeight: CGFloat = .zero
    @State private var isMessageTruncated = true
    @State private var isEditing = false
    @State private var localContent: String = ""
    @FocusState private var isFocused: Bool

    private let maxMessageLength: Int
    private let isMarkdown: Bool

    init(
        message: Message,        
        onConfigure: (() -> Void)? = nil,
        onEdit: ((String) -> Void)? = nil,
        onEditAppear: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        onTruncate: (() -> Void)? = nil,
        maxMessageLength: Int = 280
    ) {
        self.message = message
        self.onConfigure = onConfigure
        self.onEdit = onEdit
        self.onEditAppear = onEditAppear
        self.onRefresh = onRefresh
        self.onTruncate = onTruncate
        self.maxMessageLength = maxMessageLength

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
                .padding(.leading, 100)
        } else {
            aiMessage
        }
    }

    @ViewBuilder
    var userMessage: some View {
        switch message.messageType {
        case .string:
            ChatBubble(
                direction: .right,
                onConfigure: onConfigure,
                onEdit: (onEditAppear != nil) ? {
                    isEditing.toggle()
                    onEditAppear?()
                } : nil
            ) {
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
                    .focused($isFocused)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(.primary)
                    .background(Color.accentColor.opacity(0.2))
                    .onAppear(perform: {
                        DispatchQueue.main.async {
                            localContent = message.text
                            isFocused = true
                        }
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
            }

        case .markdown(let data):
            ChatBubble(
                direction: .right,
                onConfigure: onConfigure,
                onEdit: (onEditAppear != nil) ? {
                    isEditing.toggle()
                    onEditAppear?()
                } : nil
            ) {
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
                    .focused($isFocused)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
                    .foregroundColor(.primary)
                    .background(Color.accentColor.opacity(0.2))
                    .onAppear(perform: {
                        DispatchQueue.main.async {
                            localContent = message.text
                            isFocused = true
                        }
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
            }

        case .image(let data):
            ChatBubble(
                direction: .right
            ) {
                if let imageData = try? self.decodeBase64Image(data.image) {
                    Image(nsImage: imageData)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(Text("Screenshot"))
                        .accessibilityHint(Text("Ask Typeahead about this screenshot. Currently, this workflow does not support autopilot."))
                } else {
                    Text("Failed to render image")
                }
            }

        default:
            Text("Not implemented yet")
        }
    }

    @ViewBuilder
    var aiMessage: some View {
        HStack {
            switch message.messageType {
            case .string, .markdown, .tool_call:
                ChatBubble(
                    direction: .left,
                    onEdit: (onEditAppear != nil) ? {
                        isEditing.toggle()
                        onEditAppear?()
                    } : nil,
                    onRefresh: onRefresh,
                    content: {
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
                            .focused($isFocused)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 15)
                            .foregroundColor(.primary)
                            .background(Color.accentColor.opacity(0.2))
                            .onAppear(perform: {
                                DispatchQueue.main.async {
                                    localContent = message.text
                                    isFocused = true
                                }
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
                    })
            case .function_call(let functionCalls):
                ChatBubble(
                    direction: .left,
                    onRefresh: onRefresh,
                    content: {
                        Markdown {
                            Paragraph {
                                Strong("Autopilot Plan")
                            }
                            NumberedList(of: functionCalls.compactMap(getHumanReadable)) { narration in
                                ListItem {
                                    narration
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 15)
                        .foregroundColor(.primary)
                        .background(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                        .textSelection(.enabled)
                        .accessibilityElement(children: .combine)
                    })
            case .html(let data):
                ChatBubble(
                    direction: .left,
                    onRefresh: onRefresh,
                    content: {
                        WebView(html: data, dynamicHeight: $webViewHeight)
                            .frame(width: 400, height: webViewHeight)
                            .background(Color.accentColor.opacity(0.8))
                    })
            case .image(let data):
                ChatBubble(
                    direction: .left,
                    onRefresh: onRefresh,
                    content: {
                        if let imageData = try? self.decodeBase64Image(data.image) {
                            Image(nsImage: imageData)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 512, height: 512)
                                .onDrag {
                                    return NSItemProvider(item: data.toURL() as NSSecureCoding, typeIdentifier: UTType.fileURL.identifier)
                                }
                        } else {
                            EmptyView()
                        }
                    })
            case .data(let data):
                ChatBubble(
                    direction: .left,
                    onRefresh: onRefresh,
                    content: {
                        if let imageData = try? self.decodeImage(data) {
                            Image(nsImage: imageData)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 512, height: 512)
                        } else {
                            EmptyView()
                        }
                    })
            }
        }
    }

    private func getHumanReadable(functionCall: FunctionCall) -> String? {
        if let args = try? functionCall.parseArgs() {
            return args.humanReadable
        } else {
            return nil
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
    MessageView(message: Message(
        id: UUID(),
        rootId: UUID(),
        inReplyToId: nil,
        createdAt: Date(),
        rootCreatedAt: Date(),
        text: "hello bot",
        isCurrentUser: false,
        isHidden: false,
        messageType: .function_call(data: [FunctionCall(
            id: "toolcall_123",
            name: .performUIAction,
            args: [
                "actions": JSONAny.string("""
    [{"id":"AXTextField_DF3814C3","action":"AXPress","narration":"Add subject line","inputText":"Follow-Up on Typeahead Licensing Discussion"},{"id":"AXLink_638547DF","action":"AXPress","narration":"Click on this link"},{"id":"AXTextArea_B4B9E7B7","action":"AXPress","narration":"Add email body", "inputText":"Dear Kenichiro,\\n\\nI hope this message finds you well.\\n\\nI wanted to extend my gratitude for taking the time to meet with me on December 12, 2023, to discuss the potential licensing of Typeahead software for the Test.ai sales team. Your willingness to commit to a one-year license agreement for $20K is greatly appreciated and marks the beginning of what I am confident will be a fruitful collaboration.\\n\\nAs we discussed, there are some risks given that this is a new software, and we are aware of the potential for bugs. To mitigate this, I will be assigning a dedicated support engineer to ensure that your sales team is fully supported and can ramp up on the new changes efficiently.\\n\\nPlease feel free to reach out if you have any questions or need further information in the meantime.\\n\\nLooking forward to our next meeting scheduled for December 25, 2023, where we will review the progress on the action items and update on sales metrics.\\n\\nBest regards,\\n\\nJeff Hara"}]
    """)
            ]
        )])))
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
