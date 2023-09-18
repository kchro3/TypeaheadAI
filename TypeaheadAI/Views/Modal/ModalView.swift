//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI
import Markdown

struct ModalView: View {
    @Binding var showModal: Bool
    @State var incognito: Bool
    @ObservedObject var modalManager: ModalManager
    @State private var fontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    @State private var text: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isReplyLocked: Bool = false

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

            TextField(modalManager.onboardingMode ? "Replies are turned off right now." : "Ask a follow-up question...", text: $text, axis: .vertical)
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
                .disabled(modalManager.onboardingMode)
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .foregroundColor(Color.secondary.opacity(0.2))
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true

    static var previews: some View {
        let container = NSPersistentContainer(name: "TypeaheadAI")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        let context = container.viewContext

        let modalManager = ModalManager(context: context)
        modalManager.setText("hello world")

        let modalManagerWithMessages = ModalManager(context: context)
        modalManagerWithMessages.messages = [
            Message(id: UUID(), createdAt: Date(), text: "hello world", isCurrentUser: false),
            Message(id: UUID(), createdAt: Date(), text: "hello bot", isCurrentUser: true)
        ]

        let modalManagerWithErrors = ModalManager(context: context)
        modalManagerWithErrors.messages = [
            Message(id: UUID(), createdAt: Date(), text: "", isCurrentUser: false, responseError: "Request took too long"),
            Message(id: UUID(), createdAt: Date(), text: "hello bot", isCurrentUser: true)
        ]

        let modalManagerWithCodeblock = ModalManager(context: context)
        modalManagerWithCodeblock.messages = [
            Message(id: UUID(), createdAt: Date(), text: markdownString, attributed: AttributedOutput(string: markdownString, results: [parserResult]), isCurrentUser: false)
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
