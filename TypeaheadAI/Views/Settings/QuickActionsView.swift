//
//  QuickActionsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/15/23.
//

import SwiftUI

struct QuickActionRow: View {
    let quickAction: PromptEntry

    var body: some View {
        Text(quickAction.prompt ?? "none")
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(.primary.opacity(0.1))
            )
    }
}

struct QuickActionsView: View {
    @ObservedObject var promptManager: PromptManager
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    @State private var searchText = ""
    var query: Binding<String> {
        Binding {
            searchText
        } set: { newValue in
            searchText = newValue
            quickActions.nsPredicate = newValue.isEmpty
            ? nil
            : NSPredicate(format: "prompt CONTAINS %@", newValue)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                searchBar
                    .padding(10)

                Image(systemName: "plus.circle")
                    .font(.title)
                    .padding(10)
            }

            HStack {
                List(quickActions) { quickAction in
                    QuickActionRow(quickAction: quickAction)
                }
                .listStyle(.sidebar)
                .frame(maxWidth: 200)

                VStack {
                    Text("hello")
                }

                Spacer()
            }
        }
        .background(VisualEffect())
    }

    private var searchBar: some View {
        TextField(text: query) {
            Text("Search quick actions")
        }
        .textFieldStyle(.plain)
        .padding(.vertical, 5)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(.primary.opacity(0.1))
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

    return QuickActionsView(
        promptManager: promptManager
    )
    .environment(\.managedObjectContext, context)
}
