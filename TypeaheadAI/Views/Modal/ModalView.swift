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
    @ObservedObject var modalManager: ModalManager
    @State private var fontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    @State private var text: String = ""
    @State private var isAuxiliaryMenuVisible: Bool = false

    var body: some View {
        VStack {
            // Header
            modalHeaderView

            MessageHistoryView(modalManager: modalManager)

            VStack(spacing: 5) {
                if let userIntents = modalManager.userIntents,
                   userIntents.count > 0 {
                    UserIntentsView(userIntents: userIntents) { userIntent in
                        // On button click, set the new message & reset the user intents
                        modalManager.addUserMessage(userIntent, implicit: true)
                        modalManager.userIntents = nil
                    }
                }

                HStack {
                    CustomTextField(
                        text: $text,
                        placeholderText: (
                            modalManager.messages.isEmpty ?
                            "Ask me anything!" : 
                                (
                                    modalManager.userIntents == nil ?
                                    "Ask a follow-up question..." :
                                    "What do you want to do with this?"
                                )
                        ),
                        autoCompleteSuggestions: self.getPrompts()
                    ) { text in
                        if !text.isEmpty {
                            if let _ = modalManager.userIntents {
                                // If userIntents is non-nil, reset it.
                                modalManager.addUserMessage(text, implicit: true)
                                modalManager.userIntents = nil
                            } else {
                                modalManager.addUserMessage(text)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(.secondary.opacity(0.1))
                    )
                    .onAppear {
                        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
                            if event.keyCode == 125 {  // Down arrow
                                NotificationCenter.default.post(name: NSNotification.Name("ArrowKeyPressed"), object: nil, userInfo: ["direction": "down"])
                            } else if event.keyCode == 126 {  // Up arrow
                                NotificationCenter.default.post(name: NSNotification.Name("ArrowKeyPressed"), object: nil, userInfo: ["direction": "up"])
                            }
                            return event
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 15)
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .foregroundColor(Color.secondary.opacity(0.2))
    }

    @ViewBuilder
    var modalHeaderView: some View {
        HStack {
            Spacer()

            Button(action: {
                isAuxiliaryMenuVisible.toggle()
            }, label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .contentShape(Rectangle())
            })
            .buttonStyle(.plain)
            .popover(
                isPresented: $isAuxiliaryMenuVisible,
                attachmentAnchor: .rect(.bounds),
                arrowEdge: .bottom
            ) {
                AuxiliaryMenuView(
                    modalManager: modalManager,
                    settingsManager: modalManager.settingsManager!
                )
            }
        }
    }

    private func getPrompts() -> [PromptEntry] {
        if let prompts = modalManager.promptManager?.savedPrompts {
            return prompts
        } else {
            return []
        }
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true
    @State static var incognito = false

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

        let modalManagerWithIntents = ModalManager()
        modalManagerWithIntents.userIntents = [
            "testing a new idea", "test a test", "testing a test test test testing a test test test testing a test test test testing a test test test"
        ]

        // Create an in-memory Core Data store
        let container = NSPersistentContainer(name: "TypeaheadAI")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        let promptManager = PromptManager(context: container.viewContext)
        modalManager.promptManager = promptManager

        return Group {
            ModalView(showModal: $showModal, modalManager: modalManager)
            ModalView(showModal: $showModal, modalManager: modalManagerWithMessages)
            ModalView(showModal: $showModal, modalManager: modalManagerWithErrors)
            ModalView(showModal: $showModal, modalManager: modalManagerWithCodeblock)
            ModalView(showModal: $showModal, modalManager: modalManagerWithLongMessages)
            ModalView(showModal: $showModal, modalManager: modalManagerWithIntents)
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
