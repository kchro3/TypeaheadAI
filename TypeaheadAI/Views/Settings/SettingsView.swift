//
//  SettingsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case general = "General"
    case profile = "Profile"
    case quickActions = "Quick Actions"
    case history = "History"
    case incognito = "Offline Mode"
    case account = "Account Settings"
    case feedback = "Feedback"

    var id: String { self.rawValue }
}

struct SettingsView: View {
    var promptManager: QuickActionManager
    var llamaModelManager: LlamaModelManager
    @ObservedObject var supabaseManager: SupabaseManager

    @Environment(\.colorScheme) var colorScheme

    @AppStorage("settingsTab") var settingsTab: String = Tab.general.rawValue

    var body: some View {
        HStack {
            VStack {
                ForEach(Tab.allCases, id: \.self) { tab in
                    ItemRow(tab: tab, settingsTab: $settingsTab)
                }

                Spacer()
            }
            .frame(width: 150)
            .padding(10)
            .padding(.top, 25)

            viewForTab(settingsTab)
                .frame(minWidth: 600, maxWidth: .infinity, maxHeight: .infinity)
                .padding(10)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .background(VisualEffect().ignoresSafeArea())
    }

    private func viewForTab(_ tab: String) -> some View {
        guard let tab = Tab.init(rawValue: tab) else {
            return AnyView(GeneralSettingsView(promptManager: promptManager))
        }

        switch tab {
        case .profile:
            return AnyView(ProfileView())
        case .general:
            return AnyView(GeneralSettingsView(promptManager: promptManager))
        case .quickActions:
            return AnyView(QuickActionsView(promptManager: promptManager))
        case .history:
            return AnyView(HistoryListView())
        case .incognito:
            return AnyView(IncognitoModeView(llamaModelManager: llamaModelManager))
        case .account:
            return AnyView(AccountView(supabaseManager: supabaseManager))
        case .feedback:
            return AnyView(Text("Work in progress!"))
        }
    }
}

struct ItemRow: View {
    var tab: Tab
    @Binding var settingsTab: String
    @State private var isHovered = false

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack {
            Text(tab.rawValue)
                .foregroundStyle((settingsTab == tab.id || colorScheme == .dark) ? Color.white : Color.black)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    settingsTab == tab.id ? .accentColor : (isHovered ? Color.primary.opacity(0.2) : Color.clear)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            settingsTab = tab.id
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
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

        let llamaModelManager = LlamaModelManager()
        let supabaseManager = SupabaseManager()

        return Group {
            SettingsView(
                promptManager: promptManager,
                llamaModelManager: llamaModelManager,
                supabaseManager: supabaseManager
            )
            .environment(\.managedObjectContext, context)
            SettingsView(
                promptManager: promptManager,
                llamaModelManager: llamaModelManager,
                supabaseManager: supabaseManager
            )
            .environment(\.managedObjectContext, context)
        }
    }
}
