//
//  ConversationView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/3/23.
//

import SwiftUI

struct ConversationView: View {
    @StateObject var modalManager: ModalManager

    @State private var userHasScrolled: Bool = false
    @State private var previousMessageCount: Int = 0

    @Namespace var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
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
                            modalManager.replyToUserMessage(refresh: true)
                        },
                        onTruncate: {
                            modalManager.messages[index].isTruncated.toggle()
                        }
                    )
                    .padding(5)
                }

                MessagePendingView(isPending: modalManager.isPending)
                    .padding(5)

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
            }
            .onReceive(NotificationCenter.default.publisher(for: NSScrollView.willStartLiveScrollNotification)) { _ in
                userHasScrolled = true
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
