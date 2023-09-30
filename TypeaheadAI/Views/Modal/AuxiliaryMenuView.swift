//
//  AuxiliaryMenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/29/23.
//

import CoreData
import SwiftUI

struct AuxiliaryMenuView: View {
    @ObservedObject var promptManager: PromptManager

    @State private var currentPreset: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isEditingID: UUID?

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(promptManager.savedPrompts, id: \.id) { prompt in
                        Button(action: {
                            if promptManager.activePromptID == prompt.id {
                                promptManager.activePromptID = nil
                            } else {
                                promptManager.activePromptID = prompt.id
                            }
                        }, label: {
                            MenuPromptView(
                                prompt: prompt,
                                isActive: prompt.id == promptManager.activePromptID,
                                isEditing: .init(
                                    get: { self.isEditingID == prompt.id },
                                    set: { _ in
                                        self.isEditingID = (self.isEditingID == prompt.id ? nil : prompt.id)
                                        promptManager.activePromptID = prompt.id
                                    }
                                ),
                                onDelete: {
                                    promptManager.removePrompt(with: prompt.id!)
                                    if promptManager.activePromptID == prompt.id {
                                        promptManager.activePromptID = nil
                                    }
                                },
                                onUpdate: { newContent in
                                    promptManager.updatePrompt(
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

            TextField("Tell me what to do when you copy-paste.", text: $currentPreset)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(.secondary.opacity(0.1)))
                .onSubmit {
                    if !currentPreset.isEmpty {
                        promptManager.addPrompt(currentPreset)
                        currentPreset = ""
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(10)
        .frame(
            minWidth: 200,
            idealWidth: 300,
            maxWidth: 300,
            minHeight: 300,
            idealHeight: 500,
            maxHeight: 500
        )
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

    return AuxiliaryMenuView(promptManager: promptManager)
}
