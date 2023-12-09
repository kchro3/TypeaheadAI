//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import CoreData
import SwiftUI

struct ModalView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var pageSize: Int = 20
    @State private var pageOffset: Int = 0

    @FetchRequest var messageEntries: FetchedResults<MessageEntry>

    @Binding var showModal: Bool
    @ObservedObject var modalManager: ModalManager
    @State private var fontSize: CGFloat = NSFont.preferredFont(forTextStyle: .body).pointSize
    @State private var isAuxiliaryMenuVisible: Bool = false
    @State private var isSearchBarVisible: Bool = false

    @State private var searchText = ""
    @State private var debouncer: Timer?

    var query: Binding<String> {
        Binding {
            searchText
        } set: { newValue in
            searchText = newValue
            debouncer?.invalidate() // Cancel the previous timer
            debouncer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                // This block will be executed after 0.3 seconds of inactivity in typing
                messageEntries.nsPredicate = newValue.isEmpty ? NSPredicate(value: false) : NSPredicate(format: "text CONTAINS[c] %@ AND isHidden == FALSE", newValue)
            }
        }
    }

    // Initialize the FetchRequest
    init(showModal: Binding<Bool>, modalManager: ModalManager) {
        _showModal = showModal
        _modalManager = ObservedObject(initialValue: modalManager)

        let request = NSFetchRequest<MessageEntry>(entityName: "MessageEntry")
        request.predicate = NSPredicate(value: false)

        // First, sort the messages in reverse-chron by conversation (thread)
        // Then, sort the messages in chron within a conversation (thread)
        request.sortDescriptors = [
            NSSortDescriptor(key: "rootCreatedAt", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        request.fetchLimit = 10
        request.fetchOffset = 0

        _messageEntries = FetchRequest(fetchRequest: request)
    }

    var body: some View {
        VStack {
            // Header
            modalHeaderView

            if isSearchBarVisible {
                SearchResultsView(messages: messageEntries.compactMap { Message(from: $0) }) { (rootId, messageId) in
                    Task {
                        try modalManager.load(rootId: rootId)
                        isSearchBarVisible = false
                        NotificationCenter.default.post(name: .scrollToMessage, object: nil, userInfo: [
                            "messageId": messageId
                        ])
                    }
                }
            } else {
                if modalManager.messages.isEmpty {
                    RecentConversationsView(modalManager: modalManager)
                } else {
                    ConversationView(modalManager: modalManager)
                }

                ModalFooterView(
                    modalManager: modalManager,
                    clientManager: modalManager.clientManager!
                )
            }
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .foregroundColor(Color.secondary.opacity(0.2))
    }

    @ViewBuilder
    var modalHeaderView: some View {
        HStack(spacing: 0) {
            Spacer()

            ZStack {
                if isSearchBarVisible {
                    searchBar
                        .frame(maxWidth: 200)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .overlay(alignment: .trailing) {
                            Button {
                                withAnimation(.spring()) {
                                    isSearchBarVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 5)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                } else {
                    Button {
                        withAnimation(.spring()) {
                            isSearchBarVisible.toggle()
                        }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 5)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .zIndex(1) // Ensure button stays on top when searchBar is not visible
                }
            }

            Button {
                isAuxiliaryMenuVisible.toggle()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.leading, 5)
                    .padding(.trailing, 10)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
            }
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

    @ViewBuilder
    private var searchBar: some View {
        TextField(text: query) {
            Text("Search messages...")
        }
        .textFieldStyle(.plain)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primary.opacity(0.1))
        )
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManager = ModalManager(context: context)
    modalManager.clientManager = ClientManager()
    modalManager.setText("hello world", appContext: nil)
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManager = ModalManager(context: context)
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello world", isCurrentUser: false, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot", isCurrentUser: true, isHidden: false, appContext: nil)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManager = ModalManager(context: context)
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "", isCurrentUser: false, isHidden: false, appContext: nil, responseError: "Request took too long"),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot", isCurrentUser: true, isHidden: false, appContext: nil)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManager = ModalManager(context: context)
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
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: markdownString, isCurrentUser: false, isHidden: false, appContext: nil)
    ]
    return ModalView(showModal: .constant(true), modalManager: modalManager)
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManager = ModalManager(context: context)
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello world", isCurrentUser: false, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false, appContext: nil)
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

    let context = PersistenceController.preview.container.viewContext
    var modalManager = ModalManager(context: context)
    modalManager.userIntents = [
        "testing a new idea", "test a test", "testing a test test test testing a test test test testing a test test test testing a test test test"
    ]
    modalManager.clientManager = ClientManager()
    modalManager.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "", isCurrentUser: false, isHidden: false, appContext: nil, responseError: "Request took too long"),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot", isCurrentUser: true, isHidden: false, appContext: nil)
    ]

    let promptManager = QuickActionManager(context: container.viewContext, backgroundContext: container.newBackgroundContext())
    modalManager.promptManager = promptManager

    return ModalView(showModal: .constant(true), modalManager: modalManager)
}
