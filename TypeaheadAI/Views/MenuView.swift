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
    @State private var isHoveringSettings = false
    @State private var isHoveringQuit = false
    @State private var isEditingIndex: Int?
    @FocusState private var isTextFieldFocused: Bool

    private let verticalPadding: CGFloat = 5
    private let horizontalPadding: CGFloat = 10

    var body: some View {
        VStack(spacing: verticalPadding) {
            HStack {
                Text("TypeaheadAI").font(.headline)

                Spacer()

                Toggle("", isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .accentColor(.blue)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)

            Divider()
                .padding(.horizontal, horizontalPadding)

            TextField("Enter prompt...", text: $currentPreset)
                .focused($isTextFieldFocused)
                .onSubmit {
                    if !currentPreset.isEmpty {
                        promptManager.savedPrompts.insert(currentPreset, at: 0)
                        promptManager.activePromptIndex = 0
                        currentPreset = ""
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(0..<promptManager.savedPrompts.count, id: \.self) { index in
                        Button(action: {
                            if let activeIndex = promptManager.activePromptIndex {
                                if activeIndex == index {
                                    promptManager.activePromptIndex = nil
                                } else {
                                    promptManager.activePromptIndex = index
                                }
                            } else {
                                promptManager.activePromptIndex = index
                            }
                        }) {
                            MenuPromptView(
                                prompt: $promptManager.savedPrompts[index],
                                isActive: index == promptManager.activePromptIndex,
                                isEditing: .init(
                                    get: { self.isEditingIndex == index },
                                    set: { _ in self.isEditingIndex = (self.isEditingIndex == index ? nil : index) }
                                ),
                                onDelete: {
                                    promptManager.savedPrompts.remove(at: index)
                                    if promptManager.activePromptIndex == index {
                                        promptManager.activePromptIndex = nil
                                    }
                                }
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()
                .padding(.horizontal, horizontalPadding)

            VStack(spacing: 0) {
                buttonRow(title: "Settings", isHovering: $isHoveringSettings, action: {    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                })
                buttonRow(title: "Quit", isHovering: $isHoveringQuit, action: {
                    NSApplication.shared.terminate(self)
                })
            }
        }
        .padding(4)
    }

    private func buttonRow(
        title: String,
        isHovering: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
                .background(isHovering.wrappedValue ? Color.gray : Color.clear)
                .cornerRadius(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering.wrappedValue = hovering
        }
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
