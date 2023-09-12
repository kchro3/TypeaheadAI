//
//  MenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import SwiftUI
import CoreData

struct MenuView: View {
    @Binding var incognitoMode: Bool
    @ObservedObject var promptManager: PromptManager
    @Binding var isMenuVisible: Bool
    @Environment(\.managedObjectContext) private var viewContext

    @State private var currentPreset: String = ""
    @State private var isHoveringSettings = false
    @State private var isHoveringQuit = false
    @State private var isEditingID: UUID?
    @FocusState private var isTextFieldFocused: Bool

    private let verticalPadding: CGFloat = 5
    private let horizontalPadding: CGFloat = 10

    var body: some View {
        VStack(spacing: verticalPadding) {
            HStack {
                Text("TypeaheadAI").font(.headline)

                Spacer()

                Toggle("Incognito", isOn: $incognitoMode)
                    .foregroundColor(Color.secondary)
                    .toggleStyle(.switch)
                    .accentColor(.blue)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)

            Divider()
                .padding(.horizontal, horizontalPadding)

            TextField("Toggle commands (e.g. summarize this)", text: $currentPreset)
                .focused($isTextFieldFocused)
                .onSubmit {
                    if !currentPreset.isEmpty {
                        promptManager.addPrompt(currentPreset, context: viewContext)
                        currentPreset = ""
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(promptManager.savedPrompts, id: \.id) { prompt in
                        Button(action: {
                            if promptManager.activePromptID == prompt.id {
                                promptManager.activePromptID = nil
                            } else {
                                promptManager.activePromptID = prompt.id
                            }
                        }) {
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
                                    promptManager.removePrompt(with: prompt.id!, context: viewContext)
                                    if promptManager.activePromptID == prompt.id {
                                        promptManager.activePromptID = nil
                                    }
                                },
                                onUpdate: { newContent in
                                    promptManager.updatePrompt(
                                        with: prompt.id!,
                                        newContent: newContent,
                                        context: viewContext
                                    )
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
                    isMenuVisible = false
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
    @State static var incognitoMode = true
    @State static var isMenuVisible = true

    static var previews: some View {
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
            promptManager.addPrompt(prompt, context: context)
        }

        return MenuView(
            incognitoMode: $incognitoMode,
            promptManager: promptManager,
            isMenuVisible: $isMenuVisible
        )
        .environment(\.managedObjectContext, context)
        .frame(width: 300)
    }
}
