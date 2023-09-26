//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI
import Markdown

struct ModalView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @Binding var showModal: Bool
    @State var incognito: Bool
    @ObservedObject var modalManager: ModalManager
    @State private var fontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    @State private var text: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isReplyLocked: Bool = false

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
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

            CustomTextField(text: $text, autoCompleteSuggestions: self.getPrompts()) { text in
                if !text.isEmpty {
                    modalManager.addUserMessage(text, incognito: incognito)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
                    if event.keyCode == 125 {  // Down arrow
                        NotificationCenter.default.post(name: NSNotification.Name("ArrowKeyPressed"), object: nil, userInfo: ["direction": "down"])
                    } else if event.keyCode == 126 {  // Up arrow
                        NotificationCenter.default.post(name: NSNotification.Name("ArrowKeyPressed"), object: nil, userInfo: ["direction": "up"])
                    } else if event.keyCode == 36 {  // Enter key
                        NotificationCenter.default.post(name: NSNotification.Name("EnterKeyPressed"), object: nil)
                    }
                    return event
                }
            }
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .foregroundColor(Color.secondary.opacity(0.2))
    }

    private func getPrompts() -> [String] {
        if let prompts = modalManager.promptManager?.savedPrompts {
            return prompts.map { $0.prompt! }
        } else {
            return []
        }
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

        let modalManagerWithLongMessages = ModalManager()
        modalManagerWithLongMessages.messages = [
            Message(id: UUID(), text: "hello world", isCurrentUser: false),
            Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true)
        ]

        return Group {
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManager)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithMessages)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithErrors)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithCodeblock)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithLongMessages)
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
