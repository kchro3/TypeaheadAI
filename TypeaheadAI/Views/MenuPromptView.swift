//
//  MenuPromptView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/23/23.
//

import SwiftUI

struct MenuPromptView: View {
    @Binding var prompt: String
    var isActive: Bool
    @Binding var isEditing: Bool
    var onDelete: (() -> Void)?

    @State private var isHovering: Bool = false

    var body: some View {
        HStack {
            Image(systemName: isActive ? "paperclip.circle.fill" : "paperclip.circle")
                .resizable()
                .frame(width: 24, height: 24)
                .symbolRenderingMode(isActive ? .palette : .monochrome)
                .foregroundStyle(.primary, .blue)

            if isEditing {
                TextField("", text: $prompt)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    // On submit, revert back to Text view
                    // If empty, execute deletion callback
                    .onSubmit {
                        isEditing = false
                        if prompt.isEmpty {
                            onDelete?()
                        }
                    }
            } else {
                Text(prompt)
                    // On double-click, switch to TextField
                    .onTapGesture(count: 2) {
                        isEditing = true
                    }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovering ? Color.gray : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct MenuPromptView_Previews: PreviewProvider {
    @State static var prompt = "sample prompt"
    @State static var isNotEditing = false
    @State static var isEditing = true

    static var previews: some View {
        MenuPromptView(prompt: $prompt, isActive: false, isEditing: $isNotEditing)
        MenuPromptView(prompt: $prompt, isActive: true, isEditing: $isNotEditing)
        MenuPromptView(prompt: $prompt, isActive: false, isEditing: $isEditing)
        MenuPromptView(prompt: $prompt, isActive: true, isEditing: $isEditing)
    }
}
