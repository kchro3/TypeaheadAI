//
//  ModalFooterView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/15/23.
//

import SwiftUI

struct ModalFooterView: View {
    @ObservedObject var modalManager: ModalManager

    @State private var text: String = ""
    @FocusState private var isFocused: Bool
    @AccessibilityFocusState private var isAXFocused: Bool

    var body: some View {
        VStack(spacing: 5) {
            UserIntentsView(userIntents: modalManager.userIntents) { userIntent in
                Task {
                    await modalManager.addUserMessage(userIntent, isQuickAction: true, appContext: nil)
                }
            }
            .accessibilityLabel("Suggestions")

            HStack {
                CustomTextField(
                    text: $text,
                    placeholderText: (
                        modalManager.messages.isEmpty ?
                        NSLocalizedString("Ask me anything!", comment: "") :
                            (
                                modalManager.userIntents == nil ?
                                NSLocalizedString("Ask a follow-up question...", comment: "") :
                                    NSLocalizedString("What do you want to do with this?", comment: "")
                            )
                    ),
                    autoCompleteSuggestions: self.modalManager.promptManager?.getPrompts() ?? []
                ) { text in
                    if !text.isEmpty {
                        Task {
                            try await modalManager.stopDictation()
                            if modalManager.userIntents != nil {
                                await modalManager.addUserMessage(text, isQuickAction: true, appContext: nil)
                            } else {
                                await modalManager.addUserMessage(text, appContext: nil)
                            }
                        }
                    }
                }
                .focused($isFocused)
                .accessibilityFocused($isAXFocused)
                .accessibilityLabel("Message")
                .accessibilityHint("Chat with Typeahead")
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(.secondary.opacity(0.1))
                )
                .onAppear {
                    DispatchQueue.main.async {
                        isFocused = true
                        isAXFocused = true
                    }

                    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { (event) -> NSEvent? in
                        if event.keyCode == 125 {  // Down arrow
                            NotificationCenter.default.post(name: NSNotification.Name("ArrowKeyPressed"), object: nil, userInfo: ["direction": "down"])
                        } else if event.keyCode == 126 {  // Up arrow
                            NotificationCenter.default.post(name: NSNotification.Name("ArrowKeyPressed"), object: nil, userInfo: ["direction": "up"])
                        }
                        return event
                    }
                }

                if modalManager.isPending {
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
                    .accessibilityLabel("Cancel")
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
        modalManager: ModalManager(context: context)
    )
}
