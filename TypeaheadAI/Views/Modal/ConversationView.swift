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

    @StateObject var modalManager: ModalManager

    @State private var userHasScrolled: Bool = false
    @State private var previousMessageCount: Int = 0

    @Namespace var bottomID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ForEach(modalManager.messages.indices, id: \.self) { index in
                    if !modalManager.messages[index].isHidden {
                        MessageView(
                            message: modalManager.messages[index],
                            onEdit: { newContent in
                                if newContent != modalManager.messages[index].text {
                                    Task {
                                        try await modalManager.updateMessage(index: index, newContent: newContent)
                                    }
                                } else {
                                    modalManager.messages[index].isEdited.toggle()
                                }
                            },
                            onEditAppear: {
                                modalManager.messages[index].isEdited.toggle()
                            },
                            onRefresh: {
                                Task {
                                    try await modalManager.replyToUserMessage(refresh: true)
                                }
                            },
                            onTruncate: {
                                modalManager.messages[index].isTruncated.toggle()
                            }
                        )
                        .padding(5)
                    }
                }
                .markdownTheme(.custom)
                .markdownCodeSyntaxHighlighter(.custom(
                    theme: colorScheme == .dark ? HighlighterConstants.darkTheme : HighlighterConstants.lightTheme
                ))

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
        Message(id: UUID(), text: "hello world", isCurrentUser: false, isHidden: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false)
    ]

    return ConversationView(modalManager: modalManagerWithLongMessages)
}

#Preview {
    let modalManagerPending = ModalManager()
    modalManagerPending.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false, isHidden: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false)
    ]
    modalManagerPending.isPending = true

    return ConversationView(modalManager: modalManagerPending)
}

#Preview {
    let modalManagerScrolling = ModalManager()
    modalManagerScrolling.messages = [
        Message(id: UUID(), text: "hello world", isCurrentUser: false, isHidden: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: false, isHidden: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true, isHidden: false),
        Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: false, isHidden: false),
    ]

    return ConversationView(modalManager: modalManagerScrolling)
}
