//
//  RecentConversationsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/9/23.
//

import SwiftUI

struct RecentConversationsView: View {
    @AppStorage("recentConversationContextual") var contextual: Bool = true
    @StateObject var modalManager: ModalManager
    @State var messages: [Message] = []

    var body: some View {
        VStack {
            HStack {
                Text("Recent chats").font(.title)

                Spacer()

                Toggle("Filter by context", isOn: $contextual)
                    .toggleStyle(.switch)
            }
            .padding(.horizontal, 15)

            SearchResultsView(messages: messages) { (rootId, messageId) in
                Task {
                    try modalManager.load(rootId: rootId)
                    NotificationCenter.default.post(name: .scrollToMessage, object: nil, userInfo: [
                        "messageId": messageId
                    ])
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: {
            Task {
                if let messages = try await modalManager.conversationManager?.getConversations(contextual: contextual, fetchLimit: 5) {
                    self.messages = messages
                }
            }
        })
    }
}

#Preview {
    RecentConversationsView(modalManager: ModalManager(context: PersistenceController.preview.container.viewContext, speaker: Speaker()))
}
