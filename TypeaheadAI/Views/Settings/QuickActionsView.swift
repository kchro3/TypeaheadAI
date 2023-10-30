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

    @Environment(\.colorScheme) var colorScheme

    private let descWidth: CGFloat = 50

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
        if isEditing {
            readWriteView
        } else {
            readOnlyView
        }
    }

    @ViewBuilder
    var readWriteView: some View {
        VStack {
            // Read-Write Header
            HStack {
                Button(action: {
                    isEditing = false
                    onDelete?()
                }, label: {
                    Image(systemName: "trash.fill")
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
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
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
            .frame(maxWidth: .infinity)

            // Body
            VStack(alignment: .leading) {

                // Title
                HStack {
                    Text("Name")
                        .frame(width: descWidth, alignment: .trailing)

                    CustomTextField(
                        text: $mutableLabel,
                        placeholderText: quickAction.prompt ?? "Name of command",
                        autoCompleteSuggestions: [],
                        onEnter: { _ in },
                        flushOnEnter: false
                    )
                    .lineLimit(1)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                }

                // Details
                HStack {
                    Text("Prompt")
                        .frame(width: descWidth, alignment: .trailing)

                    TextEditor(text: $mutableDetails)
                        .font(.system(.body))
                        .scrollContentBackground(.hidden)
                        .lineLimit(nil)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                        )
                }

                Spacer()
            }
            .padding(10)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
        }
        .padding(15)
    }

    @ViewBuilder
    var readOnlyView: some View {
        VStack {
            // Read-only Header
            HStack {
                Spacer()

                Button(action: {
                    isEditing = true
                }, label: {
                    Image(systemName: "pencil")
                    Text("Edit")
                })
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            // Body
            VStack(alignment: .leading) {
                // Title
                Text(quickAction.prompt ?? "<none>")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(10)

                // Details
                VStack(alignment: .leading, spacing: 5) {
                    Text("Prompt")
                        .foregroundStyle(Color.accentColor)
                    Text(quickAction.details ?? "<none>")
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )

                Spacer()
            }
            .padding(10)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .leading
            )
        }
        .padding(15)
    }
}

struct QuickActionRow: View {
    let quickAction: PromptEntry
    let isActive: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        Text(quickAction.prompt ?? "none")
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(
                        isActive ?
                        Color.accentColor :
                        (colorScheme == .dark ? Color.black.opacity(0.2) : Color.secondary.opacity(0.15))
                    )
            )
    }
}

struct NewQuickActionForm: View {
    @State private var newLabel: String = ""
    @State private var newDetails: String = ""
    let onSubmit: (String, String) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) var colorScheme
    private let descWidth: CGFloat = 50
    private let height: CGFloat = 300
    private let width: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading) {
            Text("New Quick Action")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Text("Label")
                    .frame(width: descWidth, alignment: .trailing)

                CustomTextField(
                    text: $newLabel,
                    placeholderText: "Label",
                    autoCompleteSuggestions: [],
                    onEnter: { _ in },
                    flushOnEnter: false
                )
                .lineLimit(1)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
            }

            // Details
            HStack {
                Text("Prompt")
                    .frame(width: descWidth, alignment: .trailing)

                TextEditor(text: $newDetails)
                    .font(.system(.body))
                    .scrollContentBackground(.hidden)
                    .lineLimit(nil)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
            }

            HStack {
                Spacer()

                Button(action: {
                    onCancel()
                }, label: {
                    Text("Cancel")
                })
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
                .buttonStyle(.plain)

                Button(action: {
                    onSubmit(newLabel, newDetails)
                }, label: {
                    Text("Create")
                })
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(Color.accentColor)
                )
                .buttonStyle(.plain)
            }
        }
        .frame(width: width, height: height)
        .padding(15)
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
    @State private var isSheetPresented: Bool = false

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
                VStack {
                    // New button for presenting the form sheet
                    Button("New Quick Action") {
                        isSheetPresented.toggle()
                        activeQuickAction = nil
                        mutableLabel = activeQuickAction?.prompt ?? ""
                        mutableDetails = activeQuickAction?.details ?? ""
                        isEditing = false
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor)
                    )
                    .buttonStyle(.plain)
                    .sheet(isPresented: $isSheetPresented) {
                        NewQuickActionForm(onSubmit: { label, details in
                            promptManager.addPrompt(label, details: details)
                            isSheetPresented = false
                        }, onCancel: {
                            isSheetPresented = false
                        })
                    }

                    List(quickActions) { quickAction in
                        Button(action: {
                            activeQuickAction = quickAction
                            mutableLabel = activeQuickAction?.prompt ?? ""
                            mutableDetails = activeQuickAction?.details ?? ""
                            isEditing = false
                        }, label: {
                            QuickActionRow(quickAction: quickAction, isActive: quickAction.id == activeQuickAction?.id)
                        })
                        .buttonStyle(.plain)
                    }
                    .listStyle(.sidebar)
                    .frame(maxWidth: 200)
                    .scrollIndicators(.visible)
                    .scrollContentBackground(.hidden)
                }

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
    NewQuickActionForm(onSubmit: { _, _ in }, onCancel: { })
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
    newPrompt.details = "this is a sample detail"

    return QuickActionDetails(
        quickAction: newPrompt,
        isEditing: $isEditing,
        mutableLabel: $mutableLabel,
        mutableDetails: $mutableDetails
    )
    .environment(\.managedObjectContext, context)
}

#Preview {
    @State var isEditing = true
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
    .environment(\.managedObjectContext, context)
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
