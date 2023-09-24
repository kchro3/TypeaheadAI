//
//  SettingsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import SwiftUI

enum Tabs: String, CaseIterable, Identifiable {
    case general = "General"
    case profile = "Profile"
    case history = "History"
    case incognito = "Incognito Mode"

    var id: String { self.rawValue }
}

struct SettingsView: View {
    var promptManager: PromptManager

    @State var selectedTab: Tabs = .general

    var body: some View {
        NavigationView {
            List(Tabs.allCases, id: \.self) { tab in
                ItemRow(tab: tab, selectedTab: $selectedTab)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)

            viewForTab(selectedTab)
        }
    }

    private func viewForTab(_ tab: Tabs) -> some View {
        switch tab {
        case .profile:
            return AnyView(ProfileView())
        case .general:
            return AnyView(GeneralSettingsView(promptManager: promptManager))
        case .history:
            return AnyView(HistoryListView())
        case .incognito:
            return AnyView(IncognitoModeView())
        }
    }
}

struct ItemRow: View {
    var tab: Tabs
    @Binding var selectedTab: Tabs
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(tab.rawValue)
            Spacer()
        }
        .padding(.all, 15)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    selectedTab == tab ? .accentColor : (isHovered ? Color.gray.opacity(0.2) : Color.clear)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            selectedTab = tab
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
        let promptManager = PromptManager(context: context)

        // Create some sample prompts
        let samplePrompts = ["this is a sample prompt", "this is an active prompt"]
        for prompt in samplePrompts {
            let newPrompt = PromptEntry(context: context)
            newPrompt.prompt = prompt
            promptManager.addPrompt(prompt, context: context)
        }

        return Group {
            SettingsView(promptManager: promptManager)
                .environment(\.managedObjectContext, context)
            SettingsView(promptManager: promptManager, selectedTab: Tabs.general)
                .environment(\.managedObjectContext, context)
        }
    }
}
