//
//  MenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import SwiftUI
import CoreData
import KeyboardShortcuts
import SettingsAccess

struct MenuView: View {
    @ObservedObject var promptManager: PromptManager
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var settingsManager: SettingsManager
    @Binding var isMenuVisible: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("token3") var token: String?
    @AppStorage("settingsTab") var settingsTab: String?

    @State private var currentPreset: String = ""
    @State private var isHoveringChat = false
    @State private var isHoveringClearChat = false
    @State private var isHoveringSettings = false
    @State private var isHoveringSignOut = false
    @State private var isHoveringQuit = false
    @State private var isEditingID: UUID?
    @FocusState private var isTextFieldFocused: Bool

    private let verticalPadding: CGFloat = 5
    private let horizontalPadding: CGFloat = 5

    var body: some View {
        VStack(spacing: verticalPadding) {
            HStack {
                Text("TypeaheadAI").font(.headline)

                Spacer()
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)

            VStack(spacing: 0) {
                if modalManager.isVisible {
                    buttonRow(
                        title: "New chat",
                        isHovering: $isHoveringClearChat,
                        shortcut: KeyboardShortcuts.Name.chatNew
                    ) {
                        modalManager.forceRefresh()
                        NSApp.activate(ignoringOtherApps: true)
                        isMenuVisible = false
                    }
                } else {
                    buttonRow(
                        title: "Open chat",
                        isHovering: $isHoveringChat,
                        shortcut: KeyboardShortcuts.Name.chatOpen
                    ) {
                        modalManager.showModal()
                        NSApp.activate(ignoringOtherApps: true)
                        isMenuVisible = false
                    }
                }

                buttonRow(title: "Settings", isHovering: $isHoveringSettings) {
                    NSApp.activate(ignoringOtherApps: true)
                    settingsTab = Tab.general.id
                    settingsManager.showModal()
                    isMenuVisible = false
                }

                if token != nil {
                    buttonRow(title: "Sign out", isHovering: $isHoveringSignOut) {
                        token = nil
                        isMenuVisible = false
                    }
                } else {
                    buttonRow(title: "Sign in", isHovering: $isHoveringSignOut) {
                        settingsTab = Tab.account.id
                        settingsManager.showModal()
                        isMenuVisible = false
                    }
                }

                buttonRow(title: "Quit", isHovering: $isHoveringQuit) {
                    NSApplication.shared.terminate(self)
                }
            }
        }
        .padding(4)
    }

    private func buttonRow(
        title: String,
        isHovering: Binding<Bool>,
        shortcut: KeyboardShortcuts.Name? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut?.shortcut?.description ?? "")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
            .background(isHovering.wrappedValue ? .primary.opacity(0.2) : Color.clear)
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
            promptManager.addPrompt(prompt)
        }

        let modalManager = ModalManager()

        return MenuView(
            promptManager: promptManager,
            modalManager: modalManager,
            settingsManager: SettingsManager(context: context),
            isMenuVisible: $isMenuVisible
        )
        .environment(\.managedObjectContext, context)
        .frame(width: 300)
    }
}
