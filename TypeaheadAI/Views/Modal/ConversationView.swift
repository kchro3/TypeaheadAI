//
//  ConversationView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/3/23.
//

import MarkdownUI
import SwiftUI

struct ConversationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    @StateObject var modalManager: ModalManager

    @State private var userHasScrolled: Bool = false
    @State private var previousMessageCount: Int = 0

    // State vars for configuring a QuickAction
    @State private var isEditing: Bool = false
    @State private var mutableLabel: String = ""
    @State private var mutableDetails: String = ""
    @State private var isSheetPresented: Bool = false
    @State private var quickAction: PromptEntry? = nil

    @Namespace var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ForEach(modalManager.messages.indices, id: \.self) { index in
                    var message = modalManager.messages[index]
                    if !message.isHidden {
                        MessageView(
                            message: message,
                            onConfigure: (message.quickActionId == nil) ? nil : {
                                modalManager.cancelTasks()
                                quickActions.nsPredicate = NSPredicate(format: "id == %@", message.quickActionId! as CVarArg)
                                quickAction = quickActions.first
                                isSheetPresented.toggle()
                                mutableLabel = quickAction?.prompt ?? ""
                                mutableDetails = quickAction?.details ?? ""
                                isEditing = false
                            },
                            onEdit: { newContent in
                                if newContent != message.text {
                                    try? modalManager.updateMessage(index: index, newContent: newContent)
                                } else {
                                    message.isEdited.toggle()
                                }
                            },
                            onEditAppear: {
                                modalManager.cancelTasks()
                            },
                            onRefresh: {
                                Task {
                                    modalManager.cancelTasks()
                                    try await modalManager.rewindTo(index: index)
                                    try await modalManager.replyToUserMessage()
                                }
                            },
                            onTruncate: {
                                message.isTruncated.toggle()
                            }
                        )
                        .id(message.id.uuidString)
                        .padding(3)
                    }
                }
                .markdownTheme(.custom)
                .markdownCodeSyntaxHighlighter(.custom(
                    theme: colorScheme == .dark ? HighlighterConstants.darkTheme : HighlighterConstants.lightTheme
                ))

                MessagePendingView(isPending: modalManager.isPending)

                // HACK: This is a way to make sure that the chat stays scrolled to the bottom.
                Text("").font(.system(size: 1.0)).opacity(0)
                    .id(bottomID)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: modalManager.messages.last?.text as? String) { _ in
                if !userHasScrolled {
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: modalManager.messages.count) { _ in
                userHasScrolled = false
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(bottomID)
                    }
                }
            }
            .onAppear {
                userHasScrolled = false
                // Scroll to bottom if there is no saved scroll position
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSScrollView.willStartLiveScrollNotification)) { _ in
                userHasScrolled = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToMessage)) { notification in
                userHasScrolled = true
                DispatchQueue.main.async {
                    if let messageId = notification.userInfo?["messageId"] as? String {
                        withAnimation {
                            proxy.scrollTo(messageId)
                        }
                    }
                }
            }
            .sheet(isPresented: $isSheetPresented, content: {
                if let quickAction = quickAction {
                    QuickActionDetails(
                        quickAction: quickAction,
                        isEditing: $isEditing,
                        mutableLabel: $mutableLabel,
                        mutableDetails: $mutableDetails,
                        onDelete: {
                            if let quickActionId = quickAction.id {
                                self.quickAction = nil
                                modalManager.promptManager?.removePrompt(with: quickActionId)
                            }
                        },
                        onSubmit: { newLabel, newDetails in
                            if let quickActionId = quickAction.id {
                                modalManager.promptManager?.updatePrompt(
                                    with: quickActionId,
                                    newLabel: newLabel,
                                    newDetails: newDetails
                                )
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // This shouldn't happen though...
                    NewQuickActionForm(onSubmit: { label, details in
                        modalManager.promptManager?.addPrompt(label, details: details)
                        isSheetPresented = false
                    }, onCancel: {
                        isSheetPresented = false
                    })
                }
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManagerWithLongMessages = ModalManager(context: context)
    modalManagerWithLongMessages.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello world", isCurrentUser: false, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false, appContext: nil)
    ]

    return ConversationView(modalManager: modalManagerWithLongMessages)
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManagerPending = ModalManager(context: context)
    modalManagerPending.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello world", isCurrentUser: false, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false, appContext: nil)
    ]
    modalManagerPending.isPending = true

    return ConversationView(modalManager: modalManagerPending)
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let modalManagerScrolling = ModalManager(context: context)
    modalManagerScrolling.messages = [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello world", isCurrentUser: false, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: false, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false, appContext: nil),
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: false, isHidden: false, appContext: nil),
    ]

    return ConversationView(modalManager: modalManagerScrolling)
}
