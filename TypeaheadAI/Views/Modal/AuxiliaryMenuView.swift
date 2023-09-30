//
//  AuxiliaryMenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/29/23.
//

import CoreData
import SwiftUI

struct AuxiliaryMenuView: View {
    @ObservedObject var modalManager: ModalManager

    @State private var currentPreset: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isEditingID: UUID?
    @State private var isHoveringSettings: Bool = false
    @State private var isHoveringSignIn: Bool = false
    @State private var isHoveringFeedback: Bool = false

    @AppStorage("settingsTab") var settingsTab: String?

    var body: some View {
        VStack {
            VStack(spacing: 0) {
                buttonRow(title: "Settings", isHovering: $isHoveringSettings) {
                    settingsTab = Tab.general.id
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    modalManager.closeModal()
                }
                buttonRow(title: "Sign in", isHovering: $isHoveringSignIn) {
                    settingsTab = Tab.account.id
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    modalManager.closeModal()
                }
                buttonRow(title: "Feedback", isHovering: $isHoveringFeedback) {
                    settingsTab = Tab.feedback.id
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    modalManager.closeModal()
                }
            }

            Divider()
                .padding(.vertical, 0)
                .padding(.horizontal, 10)
            Spacer()

            VStack {
                HStack {
                    Text("Quick Actions")
                        .padding(.horizontal, 10)

                    Spacer()
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(modalManager.promptManager?.savedPrompts ?? [], id: \.id) { prompt in
                            Button(action: {
                                if let activePromptId = modalManager.promptManager?.activePromptID,
                                   activePromptId == prompt.id {
                                    modalManager.promptManager?.activePromptID = nil
                                } else {
                                    modalManager.promptManager?.activePromptID = prompt.id
                                }
                            }, label: {
                                MenuPromptView(
                                    prompt: prompt,
                                    isActive: prompt.id == modalManager.promptManager?.activePromptID,
                                    isEditing: .init(
                                        get: { self.isEditingID == prompt.id },
                                        set: { _ in
                                            self.isEditingID = (self.isEditingID == prompt.id ? nil : prompt.id)
                                            modalManager.promptManager?.activePromptID = prompt.id
                                        }
                                    ),
                                    onDelete: {
                                        modalManager.promptManager?.removePrompt(with: prompt.id!)
                                        if let activePromptId = modalManager.promptManager?.activePromptID,
                                           activePromptId == prompt.id {
                                            modalManager.promptManager?.activePromptID = nil
                                        }
                                    },
                                    onUpdate: { newContent in
                                        modalManager.promptManager?.updatePrompt(
                                            with: prompt.id!,
                                            newContent: newContent
                                        )
                                    }
                                )
                            })
                            .buttonStyle(.plain)
                        }
                    }
                }

                TextField("Tell me what to do when you smart-copy.", text: $currentPreset)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(.secondary.opacity(0.1)))
                    .onSubmit {
                        if !currentPreset.isEmpty {
                            modalManager.promptManager?.addPrompt(currentPreset)
                            currentPreset = ""
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(10)
            }
        }
        .frame(
            minWidth: 200,
            idealWidth: 300,
            maxWidth: 300,
            minHeight: 300,
            idealHeight: 400,
            maxHeight: 500
        )
    }

    private func buttonRow(
        title: String,
        isHovering: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(isHovering.wrappedValue ? .primary.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering.wrappedValue = hovering
        }
    }
}

#Preview {
    // Create an in-memory Core Data store
    let container = NSPersistentContainer(name: "TypeaheadAI")
    container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    container.loadPersistentStores { _, error in
        if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    let context = container.viewContext
    let promptManager = PromptManager(context: context)

    // Create some sample prompts
    let samplePrompts = ["this is a sample prompt", "this is an active prompt"]
    for prompt in samplePrompts {
        let newPrompt = PromptEntry(context: context)
        newPrompt.prompt = prompt
        promptManager.addPrompt(prompt)
    }

    let modalManager = ModalManager()
    modalManager.promptManager = promptManager

    return AuxiliaryMenuView(modalManager: modalManager)
}
