//
//  AuxiliaryMenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/29/23.
//

import CoreData
import SwiftUI
import SettingsAccess

struct AuxiliaryMenuView: View {
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var promptManager: PromptManager

    @State private var currentPreset: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var isEditingID: UUID?
    @State private var isHoveringSettings: Bool = false
    @State private var isHoveringSignIn: Bool = false
    @State private var isHoveringFeedback: Bool = false

    @AppStorage("settingsTab") var settingsTab: String?

    var body: some View {
        VStack {
            ModalHeaderView(modalManager: modalManager)

            VStack(spacing: 0) {
                if #available(macOS 14.0, *) {
                    settingsButtonRow(title: "Settings", isHovering: $isHoveringSettings) {
                        settingsTab = Tab.general.id
                        modalManager.closeModal()
                    }
                    settingsButtonRow(title: "Feedback", isHovering: $isHoveringFeedback) {
                        settingsTab = Tab.feedback.id
                        modalManager.closeModal()
                    }
                } else {
                    buttonRow(title: "Settings", isHovering: $isHoveringSettings) {
                        settingsTab = Tab.general.id
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        modalManager.closeModal()
                    }
                    buttonRow(title: "Feedback", isHovering: $isHoveringFeedback) {
                        settingsTab = Tab.feedback.id
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        modalManager.closeModal()
                    }
                }
            }
        }
        .padding(10)
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

    private func settingsButtonRow(
        title: String,
        isHovering: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        SettingsLink(label: {
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
        }, preAction: action, postAction: { })
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

    return AuxiliaryMenuView(modalManager: modalManager, promptManager: promptManager)
}
