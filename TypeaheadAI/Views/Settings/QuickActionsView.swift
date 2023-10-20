//
//  QuickActionsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/15/23.
//

import SwiftUI

struct QuickActionDetails: View {
    let quickAction: PromptEntry
    let onDelete: (() -> Void)?
    let onSubmit: ((String, String) -> Void)?

    @Binding var isEditing: Bool
    @Binding var mutableLabel: String
    @Binding var mutableDetails: String

    private let leadingPadding: CGFloat = 80

    init(
        quickAction: PromptEntry,
        isEditing: Binding<Bool>,
        mutableLabel: Binding<String>,
        mutableDetails: Binding<String>,
        onDelete: (() -> Void)? = nil,
        onSubmit: ((String, String) -> Void)? = nil
    ) {
        self.quickAction = quickAction
        self._isEditing = isEditing
        self._mutableLabel = mutableLabel
        self._mutableDetails = mutableDetails
        self.onDelete = onDelete
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(alignment: .leading) {
            ScrollView {
                VStack(alignment: .leading) {
                    if isEditing {
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
                                text: $mutableLabel,
                                placeholderText: "Name of the command",
                                autoCompleteSuggestions: [],
                                onEnter: { _ in },
                                flushOnEnter: false
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

                            TextEditor(text: $mutableDetails)
                                .font(.system(.body))
                                .scrollContentBackground(.hidden)
                                .lineLimit(nil)
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(RoundedRectangle(cornerRadius: 15)
                                    .fill(.secondary.opacity(0.1))
                                )
                        }
                    } else {
                        HStack {
                            VStack {
                                Text(quickAction.prompt ?? "<none>")
                                    .font(.title2)
                                    .padding(10)

                                VStack(alignment: .leading) {
                                    Text("Details:")
                                        .font(.headline)

                                    Text(quickAction.details ?? "<none>")
                                }
                                .padding(10)
                            }

                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            if !isEditing {
                HStack {
                    Spacer()

                    Button(action: {
                        isEditing = true
                    }, label: {
                        Text("Edit")
                    })
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(Color.secondary.opacity(0.1)))
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Button(action: {
                        isEditing = false
                        onDelete?()
                    }, label: {
                        Text("Delete")
                            .foregroundStyle(.white)
                    })
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(.red.opacity(0.4)))
                    .buttonStyle(.plain)

                    Spacer()

                    Button(action: {
                        isEditing = false
                    }, label: {
                        Text("Cancel")
                    })
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(Color.secondary.opacity(0.1)))
                    .buttonStyle(.plain)

                    Button(action: {
                        isEditing = false
                        onSubmit?(
                            mutableLabel,
                            mutableDetails
                        )
                    }, label: {
                        Text("Save")
                            .foregroundStyle(.white)
                    })
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(Color.accentColor))
                    .buttonStyle(.plain)
                }
                .padding(.leading, leadingPadding)
            }
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

    @ObservedObject var promptManager: PromptManager

    @State var activeQuickAction: PromptEntry? = nil
    @State private var isEditing: Bool = false
    @State private var mutableLabel: String = ""
    @State private var mutableDetails: String = ""

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
                        mutableLabel = activeQuickAction?.prompt ?? ""
                        mutableDetails = activeQuickAction?.details ?? ""
                        isEditing = false
                    }, label: {
                        QuickActionRow(quickAction: quickAction)
                    })
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
                .frame(maxWidth: 200)
                .scrollIndicators(.visible)
                .scrollContentBackground(.hidden)

                if let activeQuickAction = activeQuickAction {
                    QuickActionDetails(
                        quickAction: activeQuickAction,
                        isEditing: $isEditing,
                        mutableLabel: $mutableLabel,
                        mutableDetails: $mutableDetails,
                        onDelete: {
                            promptManager.removePrompt(with: activeQuickAction.id!)
                            self.activeQuickAction = nil
                        },
                        onSubmit: { newLabel, newDetails in
                            promptManager.updatePrompt(
                                with: activeQuickAction.id!,
                                newLabel: newLabel,
                                newDetails: newDetails
                            )
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
    @State var isEditing = false
    @State var mutableLabel = ""
    @State var mutableDetails = ""

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

    return QuickActionDetails(
        quickAction: newPrompt,
        isEditing: $isEditing,
        mutableLabel: $mutableLabel,
        mutableDetails: $mutableDetails
    )
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
    let samplePrompts = [
        "this is a sample prompt",
        "this is an active prompt"
    ]
    for prompt in samplePrompts {
        let newPrompt = PromptEntry(context: context)
        newPrompt.id = UUID()
        newPrompt.prompt = prompt
        promptManager.addPrompt(prompt)
    }

    return QuickActionsView(promptManager: promptManager)
        .environment(\.managedObjectContext, context)
}
