//
//  MenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import SwiftUI

struct MenuView: View {
    @Binding var isEnabled: Bool
    @ObservedObject var promptManager: PromptManager

    @State private var currentPreset: String = ""
    @State private var isHovering = false // State to keep track of hover
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack {
            HStack {
                Text("TypeaheadAI")
                    .bold()

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .accentColor(.blue)
            }

            Divider()

            ScrollView {
                VStack(spacing: 0) { // Remove spacing between rows
                    ForEach(0..<promptManager.savedPrompts.count, id: \.self) { index in
                        Button(action: {
                            if let activeIndex = promptManager.activePromptIndex {
                                if activeIndex == index {
                                    // Toggle off if already active
                                    promptManager.activePromptIndex = nil
                                } else {
                                    promptManager.activePromptIndex = index
                                }
                            } else {
                                // Set active prompt
                                promptManager.activePromptIndex = index
                            }
                        }) {
                            MenuPromptView(
                                prompt: promptManager.savedPrompts[index],
                                isActive: index == promptManager.activePromptIndex
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            TextField("Enter preset...",
                      text: $currentPreset)
            .focused($isTextFieldFocused)
            .onSubmit {
                promptManager.savedPrompts.append(currentPreset)
                // Automatically set the new prompt as active
                promptManager.activePromptIndex = promptManager.savedPrompts.count - 1
                currentPreset = ""
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .padding(.top)
            .onAppear {
                isTextFieldFocused = true
            }
        }
        .padding(10)
    }
}

struct MenuView_Previews: PreviewProvider {
    @State static var isEnabled = true
    static var promptManager = PromptManager(savedPrompts: [
        "this is a sample prompt",
        "this is an active prompt"
    ], activePromptIndex: 1)

    static var previews: some View {
        MenuView(
            isEnabled: $isEnabled,
            promptManager: promptManager
        )
        .frame(width: 300)
    }
}
