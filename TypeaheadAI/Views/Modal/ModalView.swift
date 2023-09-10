//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI

struct MessageView: View {
    let text: String
    let isUser: Bool

    var body: some View {
        Text(text)
            .foregroundColor(isUser ? .white : .primary)
            .textSelection(.enabled)
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isUser ? Color.blue.opacity(0.8) : Color.clear)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

struct ModalView: View {
    @Binding var showModal: Bool
    @State var incognito: Bool
    @ObservedObject var modalManager: ModalManager
    @State private var fontSize: CGFloat = 14.0
    @State private var text: String = ""
    @FocusState private var isTextFieldFocused: Bool

    @Namespace var bottomID

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(modalManager.messages) { message in
                            MessageView(text: message.text, isUser: message.isCurrentUser)
                        }
                        MessageView(text: modalManager.modalText, isUser: false)
                            .id(bottomID)
                    }
                    .onChange(of: modalManager.modalText) { _ in
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TextField("Refine your answer", text: $text)
                .focused($isTextFieldFocused)
                .onSubmit {
                    if !text.isEmpty {
                        modalManager.addUserMessage(text, incognito: incognito)
                        text = ""
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(5)
        }
        .font(.system(size: fontSize))
        .foregroundColor(Color.primary)
        .onAppear {
            if let savedFontSize = UserDefaults.standard.value(forKey: "UserFontSize") as? CGFloat {
                fontSize = savedFontSize
            }
        }
        .foregroundColor(Color.secondary.opacity(0.2))
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true

    static var previews: some View {
        let modalManager = ModalManager()
        modalManager.setText("hello world")

        let modalManagerWithMessages = ModalManager()
        modalManagerWithMessages.messages = [
            Message(id: UUID(), text: "hello world", isCurrentUser: false),
            Message(id: UUID(), text: "hello bot", isCurrentUser: true)
        ]

        return Group {
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManager)
            ModalView(showModal: $showModal, incognito: false, modalManager: modalManagerWithMessages)
        }
    }
}
