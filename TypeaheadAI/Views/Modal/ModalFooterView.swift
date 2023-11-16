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

    @State private var text: String = ""

    var body: some View {
        ZStack {
            if clientManager.currentStreamingTask != nil {
                HStack {
                    Spacer()
                    Button {
                        clientManager.cancelStreamingTask()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "stop.circle")
                                .font(.title2)
                            Text("Cancel")
                        }
                        .padding(5)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 10)
                }
            }

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
                        autoCompleteSuggestions: self.modalManager.promptManager?.getPrompts() ?? []
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 15)
    }
}

#Preview {
    ModalFooterView(
        modalManager: ModalManager(),
        clientManager: ClientManager()
    )
}
