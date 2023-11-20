//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI

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

    modalManager.messages = [
        Message(id: UUID(), text: markdownString, isCurrentUser: false)
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

