//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
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

struct ModalView: View {
    @Binding var showModal: Bool
    @State var incognito: Bool
    @ObservedObject var modalManager: ModalManager
    @State private var fontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    @State private var text: String = ""
    @FocusState private var isTextFieldFocused: Bool

    @Namespace var bottomID

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(modalManager.messages.indices, id: \.self) { index in
                            MessageView(message: modalManager.messages[index]) {
                                modalManager.replyToUserMessage(incognito: incognito)
                            }
                            .padding(5)
                        }
                    }
                    .onChange(of: modalManager.messages.last) { _ in
                        proxy.scrollTo(modalManager.messages.count - 1, anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TextField("Ask a follow-up question...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(8)
                .focused($isTextFieldFocused)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(.secondary.opacity(0.1))
                )
                .onSubmit {
                    if !text.isEmpty {
                        modalManager.addUserMessage(text, incognito: incognito)
                        text = ""
                    }
                }
                .onChange(of: modalManager.triggerFocus) { newValue in
                    if newValue {
                        isTextFieldFocused = true
                        modalManager.triggerFocus = false
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 15)
                .onAppear {
                    isTextFieldFocused = true
                }
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .foregroundColor(Color.secondary.opacity(0.2))
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true

    static var previews: some View {
        let modalManager = ModalManager()
        modalManager.setText("hello world")

        let modalManagerWithMessages = ModalManager()
        modalManagerWithMessages.messages = [
            Message(id: UUID(), text: "hello world", isCurrentUser: false),
            Message(id: UUID(), text: "hello bot", isCurrentUser: true)
        ]

        let modalManagerWithErrors = ModalManager()
        modalManagerWithErrors.messages = [
            Message(id: UUID(), text: "", isCurrentUser: false, responseError: "Request took too long"),
            Message(id: UUID(), text: "hello bot", isCurrentUser: true)
        ]

        let modalManagerWithCodeblock = ModalManager()
        modalManagerWithCodeblock.messages = [
            Message(id: UUID(), text: markdownString, attributed: AttributedOutput(string: markdownString, results: [parserResult]), isCurrentUser: false)
        ]

        return Group {
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManager)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithMessages)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithErrors)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithCodeblock)
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
