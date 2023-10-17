//
//  QuickActionsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/15/23.
//

import SwiftUI

struct QuickActionDetails: View {
    let quickAction: PromptEntry
    @State private var newLabel: String
    @State private var newDescription: String

    private var onSubmit: ((String) -> Void)?

    init(
        quickAction: PromptEntry,
        onSubmit: ((String) -> Void)? = nil
    ) {
        self.quickAction = quickAction
        self.newLabel = quickAction.prompt ?? ""
        self.newDescription = quickAction.details ?? quickAction.prompt ?? ""
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Editing \"\(quickAction.prompt!)\"")
                .font(.title2)
                .padding(.leading, 30)

            HStack {
                Text("Label:")

                TextField("Label", text: $newLabel)
                    .onSubmit {
                        self.onSubmit?(newLabel)
                    }
            }

            HStack {
                Text("Details:")

                TextEditor(text: $newDescription)
                    .onSubmit {
                        self.onSubmit?(newDescription)
                    }
            }

            Spacer()
        }
    }
}

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
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    @State private var activeQuickAction: PromptEntry? = nil

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
        VStack(alignment: .leading, spacing: 0) {
            Text("Quick Actions")
                .font(.largeTitle)
                .padding()

            searchBar
                .padding()

            HStack {
                List(quickActions) { quickAction in
                    Button(action: {
                        activeQuickAction = quickAction
                    }, label: {
                        QuickActionRow(quickAction: quickAction)
                    })
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
                .frame(maxWidth: 200)

                if let activeQuickAction = self.activeQuickAction {
                    QuickActionDetails(
                        quickAction: activeQuickAction,
                        onSubmit: { newValue in
                            print(newValue)
                        }
                    )
                }

                Spacer()
            }
        }
        .background(VisualEffect())
    }

    private var searchBar: some View {
        TextField(text: query) {
            Text("Search quick actions...")
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

    // Create some sample prompts
    let samplePrompts = [
        "this is a sample prompt",
        "this is an active prompt"
    ]
    for prompt in samplePrompts {
        let newPrompt = PromptEntry(context: context)
        newPrompt.id = UUID()
        newPrompt.prompt = prompt
    }

    return QuickActionsView()
        .environment(\.managedObjectContext, context)
}
