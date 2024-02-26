//
//  MenuView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import Sparkle
import SwiftUI
import CoreData
import KeyboardShortcuts
import SettingsAccess

final class MenuViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct MenuView: View {
    // Alphabetize
    @Binding var isOnline: Bool
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var promptManager: QuickActionManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var supabaseManager: SupabaseManager

    @ObservedObject private var menuViewModel: MenuViewModel
    private let updater: SPUUpdater

    @Binding var isMenuVisible: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("settingsTab") var settingsTab: String?
    @AppStorage("selectedModel") private var selectedModelURL: URL?

    @State private var currentPreset: String = ""
    @State private var isEditingID: UUID?
    @FocusState private var isTextFieldFocused: Bool

    private let verticalPadding: CGFloat = 5
    private let horizontalPadding: CGFloat = 5

    init(
        isOnline: Binding<Bool>,
        modalManager: ModalManager,
        promptManager: QuickActionManager,
        settingsManager: SettingsManager,
        supabaseManager: SupabaseManager,
        isMenuVisible: Binding<Bool>,
        updater: SPUUpdater
    ) {
        self._isOnline = isOnline
        self.modalManager = modalManager
        self.promptManager = promptManager
        self.settingsManager = settingsManager
        self.supabaseManager = supabaseManager
        self._isMenuVisible = isMenuVisible
        self.updater = updater
        self.menuViewModel = MenuViewModel(updater: updater)
    }

    var body: some View {
        VStack(spacing: verticalPadding) {
            // Menu Header
            HStack {
                Text("Typeahead").font(.headline)

                Spacer()

                Toggle("Online", isOn: $isOnline)
                    .accessibilityLabel("Toggle Typeahead")
                    .accessibilityHint("Disable Typeahead without quitting the app")
                    .scaleEffect(0.8)
                    .foregroundColor(Color.secondary)
                    .toggleStyle(.switch)
                    .accentColor(.blue)
                    .padding(0)
            }
            .padding(.vertical, verticalPadding)
            .padding(.leading, horizontalPadding)
            .padding(.trailing, -8)

            VStack(spacing: 0) {
                if modalManager.isPending {
                    MenuButtonView(
                        title: NSLocalizedString("Cancel task", comment: ""),
                        shortcut: .cancelTasks
                    ) {
                        modalManager.cancelTasks()
                    }
                }

                if modalManager.isVisible {
                    MenuButtonView(
                        title: NSLocalizedString("New chat", comment: ""),
                        shortcut: .chatNew
                    ) {
                        Task {
                            modalManager.forceRefresh()
                            NSApp.activate(ignoringOtherApps: true)
                            isMenuVisible = false
                        }
                    }
                } else {
                    MenuButtonView(
                        title: NSLocalizedString("Open chat", comment: ""),
                        shortcut: KeyboardShortcuts.Name.chatOpen
                    ) {
                        modalManager.showModal()
                        NSApp.activate(ignoringOtherApps: true)
                        isMenuVisible = false
                    }
                }

                MenuButtonView(
                    title: NSLocalizedString("Feedback", comment: "")
                ) {
                    modalManager.closeModal()
                    settingsManager.showModal(tab: .feedback)
                    isMenuVisible = false
                }

                Divider()
                    .padding(.vertical, verticalPadding)
                    .padding(.horizontal, horizontalPadding)

                MenuButtonView(
                    title: NSLocalizedString("Settings", comment: "")
                ) {
                    modalManager.closeModal()
                    settingsManager.showModal()
                    isMenuVisible = false
                }

                MenuButtonView(
                    title: NSLocalizedString("Check for updates", comment: "")
                ) {
                    updater.checkForUpdates()
                    isMenuVisible = false
                }

                if supabaseManager.uuid != nil {
                    MenuButtonView(
                        title: NSLocalizedString("Sign out", comment: "")
                    ) {
                        Task {
                            isMenuVisible = false
                            try await supabaseManager.signout()
                        }
                    }
                } else {
                    MenuButtonView(
                        title: NSLocalizedString("Sign in", comment: "")
                    ) {
                        modalManager.closeModal()
                        settingsManager.showModal(tab: .account)
                        isMenuVisible = false
                    }
                }

                MenuButtonView(
                    title: NSLocalizedString("Quit", comment: "")
                ) {
                    NSApplication.shared.terminate(self)
                }
            }
        }
        .padding(4)
        .onAppear {
            Task {
                if supabaseManager.uuid != nil {
                    try await supabaseManager.signIn()
                }
            }
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
        let promptManager = QuickActionManager(context: context, backgroundContext: context)

        // Create some sample prompts
        let samplePrompts = ["this is a sample prompt", "this is an active prompt"]
        for prompt in samplePrompts {
            let newPrompt = PromptEntry(context: context)
            newPrompt.prompt = prompt
            promptManager.addPrompt(prompt)
        }

        let modalManager = ModalManager(context: context)
        let updaterController = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)

        return MenuView(
            isOnline: .constant(true),
            modalManager: modalManager,
            promptManager: promptManager,
            settingsManager: SettingsManager(context: context),
            supabaseManager: SupabaseManager(),
            isMenuVisible: $isMenuVisible,
            updater: updaterController.updater
        )
        .environment(\.managedObjectContext, context)
        .frame(width: 300)
    }
}
