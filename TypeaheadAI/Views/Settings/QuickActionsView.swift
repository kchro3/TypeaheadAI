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
    private let leadingPadding: CGFloat = 80

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
            Text("Editing...")
                .font(.title2)
                .padding(10)
                .padding(.leading, leadingPadding)

            HStack {
                HStack {
                    Spacer()
                    Text("Command:")
                }
                .frame(width: leadingPadding)

                CustomTextField(
                    text: $newLabel,
                    placeholderText: "Name of the command",
                    autoCompleteSuggestions: [],
                    onEnter: { newValue in
                        self.onSubmit?(newValue)
                    }
                )
                .lineLimit(1)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(.secondary.opacity(0.1))
                )
            }

            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Spacer()

                        Text("Details:")
                            .padding(.top, 5)
                    }

                    Spacer()
                }
                .frame(width: leadingPadding)

                CustomTextField(
                    text: $newDescription,
                    placeholderText: "Describe what this action should do",
                    autoCompleteSuggestions: [],
                    onEnter: { newValue in
                        self.onSubmit?(newValue)
                    },
                    dynamicHeight: false
                )
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(.secondary.opacity(0.1))
                )
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

class QuickActionsViewModel: ObservableObject {
    @Published var activeQuickAction: PromptEntry? = nil
}

struct QuickActionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    @StateObject private var vm: QuickActionsViewModel = QuickActionsViewModel()

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
                        vm.activeQuickAction = quickAction
                    }, label: {
                        QuickActionRow(quickAction: quickAction)
                    })
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
                .frame(maxWidth: 200)
                .scrollIndicators(.visible)
                .scrollContentBackground(.hidden)

                if let activeQuickAction = vm.activeQuickAction {
                    QuickActionDetails(
                        quickAction: activeQuickAction,
                        onSubmit: { newValue in
                            print(newValue)
                        }
                    )
                } else {
                    VStack {
                        Text(
                        """
                        Quickly search for specific quick actions using the search bar or scroll through the list to find the one you want.

                        You can then edit or delete them, or create a brand new one
                        """
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding()

                        Spacer()
                    }
                }

                Spacer()
            }
        }
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

    let newPrompt = PromptEntry(context: context)
    newPrompt.id = UUID()
    newPrompt.prompt = "this is a sample prompt"

    return QuickActionDetails(quickAction: newPrompt)
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
