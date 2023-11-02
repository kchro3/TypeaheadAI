//
//  QuickActionDetails.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/1/23.
//

import SwiftUI

struct QuickActionDetails: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @Environment(\.colorScheme) var colorScheme

    let quickAction: PromptEntry
    let onDelete: (() -> Void)?
    let onSubmit: ((String, String) -> Void)?

    @FetchRequest(entity: HistoryEntry.entity(), sortDescriptors: []) var history: FetchedResults<HistoryEntry>
    @State private var selectedRow: HistoryEntry.ID?
    @State private var isSheetPresented: Bool = false
    @State private var confirmDelete: Bool = false

    @Binding var isEditing: Bool
    @Binding var mutableLabel: String
    @Binding var mutableDetails: String

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
        self._history = FetchRequest<HistoryEntry>(
            sortDescriptors: [],
            predicate: NSPredicate(format: "quickActionId == %@", quickAction.id! as CVarArg)
        )
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
        ScrollView {
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
                            .frame(minHeight: 50)
                    }

                    // Examples
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Examples")
                            .foregroundStyle(Color.accentColor)

                        Table(history, selection: $selectedRow) {
                            TableColumn("Date") { entry in
                                Text(entry.timestamp?.formatted() ?? "unknown")
                            }
                            TableColumn("Copied Text") { entry in
                                Text(entry.copiedText ?? "none")
                            }
                            TableColumn("Pasted Text") { entry in
                                Text(entry.pastedResponse ?? "none")
                            }
                            TableColumn("Active App") { entry in
                                Text(entry.activeAppName ?? "unknown")
                            }
                            TableColumn("Active URL") { entry in
                                Text(entry.activeUrl ?? "none")
                            }
                        }
                        .onDeleteCommand(perform: {
                            confirmDelete = true
                        })
                        .alert(isPresented: $confirmDelete) {
                            Alert(
                                title: Text("Are you sure you want to delete this example?"),
                                message: Text("If you delete this, TypeaheadAI will forget about this example, and this action cannot be undone."),
                                primaryButton: .destructive(Text("Delete")) {
                                    deleteSelectedRow()
                                },
                                secondaryButton: .cancel()
                            )
                        }
                        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    Spacer()

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

    @ViewBuilder
    var readOnlyView: some View {
        ScrollView {
            VStack {
                // Read-only Header
                HStack {
                    // Title
                    Text(quickAction.prompt ?? "<none>")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(10)

                    Spacer()

                    Button(action: {
                        isEditing = true
                    }, label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                        )
                    })
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)

                // Body
                VStack(alignment: .leading) {
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

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Examples")
                            .foregroundStyle(Color.accentColor)

                        Table(history, selection: $selectedRow) {
                            TableColumn("Date") { entry in
                                Text(entry.timestamp?.formatted() ?? "unknown")
                            }
                            TableColumn("Copied Text") { entry in
                                Text(entry.copiedText ?? "none")
                            }
                            TableColumn("Pasted Text") { entry in
                                Text(entry.pastedResponse ?? "none")
                            }
                            TableColumn("Active App") { entry in
                                Text(entry.activeAppName ?? "unknown")
                            }
                            TableColumn("Active URL") { entry in
                                Text(entry.activeUrl ?? "none")
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
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

    private func deleteSelectedRow() {
        if let selectedRow = selectedRow,
           let historyId = selectedRow {
            let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", historyId as CVarArg)

            do {
                let fetchedObjects = try managedObjectContext.fetch(fetchRequest)
                if let object = fetchedObjects.first {
                    managedObjectContext.delete(object)

                    do {
                        try managedObjectContext.save()
                    } catch {
                        // Handle the error appropriately
                        print("Error deleting entry: \(error.localizedDescription)")
                    }
                }
            } catch {
                // Handle the error appropriately
                print("Error fetching entry: \(error.localizedDescription)")
            }
        }
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
    newPrompt.details = "this is a sample detail"

    // Create a few sample history entries
    for i in 0..<5 {
        let entry = HistoryEntry(context: context)
        entry.id = UUID()
        entry.copiedText = "copy \(i)"
        entry.pastedResponse = "paste \(i)"
        entry.quickActionId = newPrompt.id
    }

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

    // Create a few sample history entries
    for i in 0..<5 {
        let entry = HistoryEntry(context: context)
        entry.id = UUID()
        entry.copiedText = "copy \(i)"
        entry.pastedResponse = "paste \(i)"
        entry.quickActionId = newPrompt.id
    }

    return QuickActionDetails(
        quickAction: newPrompt,
        isEditing: $isEditing,
        mutableLabel: $mutableLabel,
        mutableDetails: $mutableDetails
    )
    .environment(\.managedObjectContext, context)
}
