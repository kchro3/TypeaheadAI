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
    @ObservedObject var promptManager: QuickActionManager
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var supabaseManager: SupabaseManager

    @Binding var isMenuVisible: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("token3") var token: String?
    @AppStorage("settingsTab") var settingsTab: String?
    @AppStorage("selectedModel") private var selectedModelURL: URL?

    @State private var currentPreset: String = ""
    @State private var isEditingID: UUID?
    @FocusState private var isTextFieldFocused: Bool

    private let verticalPadding: CGFloat = 5
    private let horizontalPadding: CGFloat = 5

    var body: some View {
        VStack(spacing: verticalPadding) {
            // Menu Header
            HStack {
                Text("TypeaheadAI").font(.headline)

                Spacer()

                Toggle("Online", isOn: $modalManager.online)
                    .scaleEffect(0.8)
                    .onChange(of: modalManager.online) { online in
                        if let manager = modalManager.clientManager?.llamaModelManager,
                           !online,
                           let _ = selectedModelURL {
                            Task {
                                do {
                                    try await manager.load()
                                } catch let error {
                                    print(error.localizedDescription)
                                }
                            }
                        }
                    }
                    .foregroundColor(Color.secondary)
                    .toggleStyle(.switch)
                    .accentColor(.blue)
                    .padding(0)
            }
            .padding(.vertical, verticalPadding)
            .padding(.leading, horizontalPadding)
            .padding(.trailing, -8)

            VStack(spacing: 0) {
                MenuButtonView(
                    title: "Quick Actions"
                ) {
                    settingsManager.showModal(tab: .quickActions)
                    isMenuVisible = false
                }

                if modalManager.isVisible {
                    MenuButtonView(
                        title: "New chat",
                        shortcut: KeyboardShortcuts.Name.chatNew
                    ) {
                        modalManager.forceRefresh()
                        NSApp.activate(ignoringOtherApps: true)
                        isMenuVisible = false
                    }
                } else {
                    MenuButtonView(
                        title: "Open chat",
                        shortcut: KeyboardShortcuts.Name.chatOpen
                    ) {
                        modalManager.showModal()
                        NSApp.activate(ignoringOtherApps: true)
                        isMenuVisible = false
                    }
                }

                Divider()
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, horizontalPadding)

                MenuButtonView(title: "Settings") {
                    settingsManager.showModal()
                    isMenuVisible = false
                }

                if supabaseManager.uuid != nil {
                    MenuButtonView(title: "Sign out") {
                        Task {
                            token = nil
                            isMenuVisible = false
                            try await supabaseManager.signout()
                        }
                    }
                } else {
                    MenuButtonView(title: "Sign in") {
                        settingsManager.showModal(tab: .account)
                        isMenuVisible = false
                    }
                }

                MenuButtonView(title: "Quit") {
                    NSApplication.shared.terminate(self)
                }
            }
        }
        .padding(4)
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
        let promptManager = QuickActionManager(context: context)

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
            supabaseManager: SupabaseManager(),
            isMenuVisible: $isMenuVisible
        )
        .environment(\.managedObjectContext, context)
        .frame(width: 300)
    }
}
