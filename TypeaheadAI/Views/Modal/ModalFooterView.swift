//
//  ModalFooterView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/15/23.
//

import SwiftUI

struct ModalFooterView: View {
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var clientManager: ClientManager
    @ObservedObject var functionManager: FunctionManager

    @State private var text: String = ""

    var body: some View {
        VStack(spacing: 5) {
            if let userIntents = modalManager.userIntents,
               userIntents.count > 0 {
                UserIntentsView(userIntents: userIntents) { userIntent in
                    Task {
                        await modalManager.addUserMessage(userIntent, isQuickAction: true, appContext: nil)
                    }
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
                    autoCompleteSuggestions: self.modalManager.promptManager?.getPrompts() ?? []
                ) { text in
                    if !text.isEmpty {
                        Task {
                            if modalManager.userIntents != nil {
                                await modalManager.addUserMessage(text, isQuickAction: true, appContext: nil)
                            } else {
                                await modalManager.addUserMessage(text, appContext: nil)
                            }
                        }
                    } else if let cachedAppInfo = modalManager.cachedAppInfo {
                        Task {
                            try await modalManager.continueReplying(appInfo: cachedAppInfo)
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

                if clientManager.isExecuting || functionManager.isExecuting {
                    Button {
                        modalManager.cancelTasks()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "stop.circle")
                                .font(.title2)
                            Text("Cancel")
                        }
                        .padding(5)
                    }
                    .buttonStyle(.plain)
                    .transition(.slide.animation(.spring))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 15)
    }
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    return ModalFooterView(
        modalManager: ModalManager(context: context),
        clientManager: ClientManager(),
        functionManager: FunctionManager()
    )
}
