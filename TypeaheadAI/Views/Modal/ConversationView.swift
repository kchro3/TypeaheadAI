//
//  ConversationView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/3/23.
//

import SwiftUI

struct ConversationView: View {
    @StateObject var modalManager: ModalManager

    @Namespace var bottomID

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                LazyVStack {
                    ForEach(modalManager.messages.indices, id: \.self) { index in
                        MessageView(
                            message: modalManager.messages[index],
                            onEdit: { newContent in
                                if newContent != modalManager.messages[index].text {
                                    modalManager.updateMessage(index: index, newContent: newContent)
                                } else {
                                    modalManager.messages[index].isEdited.toggle()
                                }
                            },
                            onEditAppear: {
                                modalManager.messages[index].isEdited.toggle()
                            },
                            onRefresh: {
                                modalManager.replyToUserMessage()
                            },
                            onTruncate: {
                                modalManager.messages[index].isTruncated.toggle()
                            }
                        )
                        .padding(5)
                    }

                    // Invisible if not pending. LazyVStack has perf issues
                    // if you use conditionals, so this is intentional.
                    MessagePendingView(isPending: modalManager.isPending)
                        .padding(5)
                        .id(bottomID)
                }
                .scrollContentBackground(.hidden)
                .onChange(of: modalManager.messages) { _ in
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let modalManagerWithLongMessages = ModalManager()
    modalManagerWithLongMessages.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true)
    ]

    return ConversationView(modalManager: modalManagerWithLongMessages)
}

#Preview {
    let modalManagerPending = ModalManager()
    modalManagerPending.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true)
    ]
    modalManagerPending.isPending = true

    return ConversationView(modalManager: modalManagerPending)
}

#Preview {
    let modalManagerScrolling = ModalManager()
    modalManagerScrolling.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: false),
    ]

    return ConversationView(modalManager: modalManagerScrolling)
}
