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

            ConversationView(modalManager: modalManager)

            ModalFooterView(
                modalManager: modalManager,
                clientManager: modalManager.clientManager!
            )
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .foregroundColor(Color.secondary.opacity(0.2))
    }

    @ViewBuilder
    var textInput: some View {
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
            autoCompleteSuggestions: self.modalManager.promptManager?.getPrompts() ?? []
        ) { text in
            if !text.isEmpty {
                Task {
                    if let _ = modalManager.userIntents {
                        // If userIntents is non-nil, reset it.
                        try await modalManager.addUserMessage(text, implicit: true)
                        modalManager.userIntents = nil
                    } else {
                        try await modalManager.addUserMessage(text)
                    }
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
}

#Preview {
    var modalManager = ModalManager()
    modalManager.clientManager = ClientManager()
    modalManager.setText("hello world")
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    var modalManager = ModalManager()
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false),
        Message(id: UUID(), text: "hello bot", isCurrentUser: true)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    var modalManager = ModalManager()
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), text: "", isCurrentUser: false, responseError: "Request took too long"),
        Message(id: UUID(), text: "hello bot", isCurrentUser: true)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    var modalManager = ModalManager()
    modalManager.clientManager = ClientManager()

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
"""

    let parserResult: ParserResult = {
        let document = Document(parsing: markdownString)
        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)
        var parser = MarkdownAttributedStringParser(isDarkMode: isDarkMode)
        return parser.parserResults(from: document)[0]
    }()

    modalManager.messages = [
        Message(id: UUID(), text: markdownString, attributed: AttributedOutput(string: markdownString, results: [parserResult]), isCurrentUser: false)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    var modalManager = ModalManager()
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    // Create an in-memory Core Data store
    let container = NSPersistentContainer(name: "TypeaheadAI")
    container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    container.loadPersistentStores { _, error in
        if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    var modalManager = ModalManager()
    modalManager.userIntents = [
        "testing a new idea", "test a test", "testing a test test test testing a test test test testing a test test test testing a test test test"
    ]
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), text: "", isCurrentUser: false, responseError: "Request took too long"),
        Message(id: UUID(), text: "hello bot", isCurrentUser: true)
    ]

    let promptManager = QuickActionManager(context: container.viewContext, backgroundContext: container.newBackgroundContext())
    modalManager.promptManager = promptManager

    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

