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
        VStack {
            ScrollView {
                // Body
                VStack(alignment: .leading) {
                    // Details
                    Text("Plan")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    TextEditor(text: $mutableDetails)
                        .font(.system(.body))
                        .scrollContentBackground(.hidden)
                        .lineLimit(10)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                        )
                        .frame(minHeight: 60)

                    Text("Examples")
                        .font(.title3)
                        .foregroundStyle(Color.accentColor)

                    // Examples
                    Table(history, selection: $selectedRow) {
                        TableColumn("Copied Text") { entry in
                            Text(entry.copiedText ?? "none")
                        }
                        TableColumn("Pasted Text") { entry in
                            Text(entry.pastedResponse ?? "none")
                        }
                    }
                    .contextMenu(menuItems: {
                        Button {
                            selectedRow = nil
                            isSheetPresented = true
                        } label: {
                            Text("Add New Example")
                        }

                        if let selectedRow = selectedRow, let _ = selectedRow {
                            Button {
                                isSheetPresented = true
                            } label: {
                                Text("Edit")
                            }

                            Button {
                                confirmDelete = true
                            } label: {
                                Text("Delete")
                            }
                        }
                    })
                    .sheet(isPresented: $isSheetPresented, onDismiss: {
                        isSheetPresented = false
                    }) {
                        QuickActionExampleForm(
                            selectedRow: selectedRow,
                            onFetch: self.fetchHistoryEntry,
                            onSubmit: { (copiedText, pastedText) in
                                self.upsertExample(
                                    copiedText: copiedText,
                                    pastedText: pastedText
                                )
                                isSheetPresented = false
                            },
                            onCancel: {
                                isSheetPresented = false
                            }
                        )
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
                    .cornerRadius(10)
                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: .infinity, alignment: .leading)
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
            }

            // Read-Write Footer
            HStack {
                Button(action: {
                    isEditing = false
                    onDelete?()
                }, label: {
                    HStack {
                        Image(systemName: "trash.fill")
                            .foregroundStyle(.white)
                        Text("Delete")
                            .foregroundStyle(.white)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(.red))
                })
                .buttonStyle(.plain)

                Spacer()

                Button(action: {
                    isEditing = false
                }, label: {
                    Text("Cancel")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                        )
                })
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
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor))
                })
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(15)
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
                        Text("Plan")
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
                            TableColumn("Copied Text") { entry in
                                Text(entry.copiedText ?? "none")
                            }
                            TableColumn("Pasted Text") { entry in
                                Text(entry.pastedResponse ?? "none")
                            }
                        }
                        .frame(maxWidth: .infinity,  minHeight: 150, maxHeight: .infinity, alignment: .leading)
                        .cornerRadius(10)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .leading
                )
            }
        }            
        .padding(15)
    }

    private func fetchHistoryEntry(uuid: UUID) -> HistoryEntry? {
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)

        do {
            let fetchedObjects = try managedObjectContext.fetch(fetchRequest)
            if let object = fetchedObjects.first {
                return object
            }
        } catch {
            // Handle the error appropriately
            print("Error fetching entry: \(error.localizedDescription)")
        }

        return nil
    }

    private func upsertExample(copiedText: String, pastedText: String) {
        if let selectedRow = selectedRow,
           let historyId = selectedRow {
            // Update flow
            let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", historyId as CVarArg)

            do {
                let fetchedObjects = try managedObjectContext.fetch(fetchRequest)
                if let object = fetchedObjects.first {
                    object.copiedText = copiedText
                    object.pastedResponse = pastedText

                    try managedObjectContext.save()
                }
            } catch {
                // Handle the error appropriately
                print("Error updating entry: \(error.localizedDescription)")
            }
        } else {
            // Create new example flow
            let newEntry = HistoryEntry(context: managedObjectContext)
            newEntry.id = UUID()
            newEntry.timestamp = Date()
            newEntry.quickActionId = quickAction.id
            newEntry.copiedText = copiedText
            newEntry.pastedResponse = pastedText
            newEntry.numMessages = Int16(0)

            do {
                try managedObjectContext.save()
            } catch {
                // Handle the error appropriately
                print("Error writing entry: \(error.localizedDescription)")
            }
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
