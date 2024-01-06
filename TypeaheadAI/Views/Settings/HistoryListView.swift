//
//  HistoryListView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import SwiftUI
import CoreData

enum HistoryTab: String, CaseIterable, Identifiable {
    case messages = "Messages"
    case smartCopyPastes = "Smart Copy-Pastes"
    case intents = "Intents"

    var id: String { self.rawValue }
}

struct HistoryListView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: MessageEntry.entity(), sortDescriptors: []) var messages: FetchedResults<MessageEntry>
    @FetchRequest(entity: IntentEntry.entity(), sortDescriptors: []) var intents: FetchedResults<IntentEntry>
    @FetchRequest(entity: HistoryEntry.entity(), sortDescriptors: []) var history: FetchedResults<HistoryEntry>
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    @State private var showMessagesAlert = false
    @State private var showHistoryAlert = false
    @State private var showIntentsAlert = false

    @AppStorage("numSmartCopies") var numSmartCopies: Int?
    @AppStorage("numSmartPastes") var numSmartPastes: Int?
    @AppStorage("numSmartCuts") var numSmartCuts: Int?
    @AppStorage("historyTab") var historyTab: String = HistoryTab.messages.id
    @AppStorage("isHistoryEnabled") private var isHistoryEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History").font(.title)

            Text("You can view and manage your history here.")

            Divider()

            HStack {
                Text("^[\(numSmartCopies ?? 0) smart-copy](inflect: true)")
                Text("^[\(numSmartCuts ?? 0) smart-cut](inflect: true)")
                Text("^[\(numSmartPastes ?? 0) smart-paste](inflect: true)")

                Spacer()

                Toggle(isOn: $isHistoryEnabled) {
                    Text("Keep message history")
                }
            }

            Divider()

            TabView {
                messagesTable
                    .tabItem {
                        Image(systemName: "1.square.fill")
                        Text(HistoryTab.messages.id)
                    }

                smartCopyPastesTable
                    .tabItem {
                        Image(systemName: "2.square.fill")
                        Text(HistoryTab.smartCopyPastes.id)
                    }

                intentsTable
                    .tabItem {
                        Image(systemName: "3.square.fill")
                        Text(HistoryTab.intents.id)
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    @ViewBuilder
    private var messagesTable: some View {
        VStack {
            Table(messages) {
                TableColumn("Date") { entry in
                    Text(entry.createdAt?.formatted() ?? "unknown")
                }
                TableColumn("Text") { entry in
                    Text(entry.text ?? "none")
                }
                TableColumn("Active App") { entry in
                    if let data = entry.serializedAppContext?.data(using: .utf8),
                       let appContext = try? JSONDecoder().decode(AppContext.self, from: data) {
                        Text(appContext.appName ?? "unknown")
                    } else {
                        Text("unknown")
                    }
                }
                TableColumn("Active URL") { entry in
                    if let data = entry.serializedAppContext?.data(using: .utf8),
                       let appContext = try? JSONDecoder().decode(AppContext.self, from: data) {
                        Text(appContext.url?.absoluteString ?? "unknown")
                    } else {
                        Text("unknown")
                    }
                }
            }

            HStack {
                Spacer()

                Button("Clear Messages") {
                    showMessagesAlert = true
                }
                .alert(isPresented: $showMessagesAlert) {
                    Alert(
                        title: Text("Confirm clearing messages"),
                        message: Text("Are you sure you want to all messages? This action cannot be undone."),
                        primaryButton: .destructive(Text("Clear")) {
                            clearMessages(context: managedObjectContext)
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .padding(5)
    }

    @ViewBuilder
    private var intentsTable: some View {
        VStack {
            Table(intents) {
                TableColumn("Date") { entry in
                    Text(entry.updatedAt?.formatted() ?? "unknown")
                }
                TableColumn("Copied Text") { entry in
                    Text(entry.copiedText ?? "none")
                }
                TableColumn("Prompt") { entry in
                    Text(entry.prompt ?? "none")
                }
                TableColumn("Active App") { entry in
                    Text(entry.appName ?? "unknown")
                }
                TableColumn("Active Bundle ID") { entry in
                    Text(entry.bundleIdentifier ?? "none")
                }
                TableColumn("Active URL") { entry in
                    Text(entry.url ?? "none")
                }
            }

            HStack {
                Spacer()

                Button("Clear Intents") {
                    showIntentsAlert = true
                }
                .alert(isPresented: $showIntentsAlert) {
                    Alert(
                        title: Text("Confirm clearing intents"),
                        message: Text("Are you sure you want to the intents? This action cannot be undone."),
                        primaryButton: .destructive(Text("Clear")) {
                            clearIntents(context: managedObjectContext)
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .padding(5)
    }

    @ViewBuilder
    private var smartCopyPastesTable: some View {
        VStack {
            Table(history) {
                TableColumn("Date") { entry in
                    Text(entry.timestamp?.formatted() ?? "unknown")
                }
                TableColumn("Quick Action ID") { entry in
                    Text(entry.quickActionId?.uuidString ?? "none")
                }
                TableColumn("Quick Action") { entry in
                    let quickAction = quickActions.first(where: {
                        $0.id == entry.quickActionId
                    })

                    Text(quickAction?.prompt ?? "none")
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

            HStack {
                Spacer()

                Button("Clear history") {
                    showHistoryAlert = true
                }
                .alert(isPresented: $showHistoryAlert) {
                    Alert(
                        title: Text("Confirm clearing history"),
                        message: Text("Are you sure you want to the smart copy-paste history? This action cannot be undone."),
                        primaryButton: .destructive(Text("Clear")) {
                            clearHistory(context: managedObjectContext)
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .padding(5)
    }

    private func clearMessages(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()

        do {
            let objects = try context.fetch(fetchRequest)
            // Delete the objects
            for object in objects {
                context.delete(object)
            }

            try context.save()
        } catch let error as NSError {
            // Handle the error
            print("Could not clear messages: \(error), \(error.userInfo)")
        }
    }

    private func clearHistory(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()

        do {
            let objects = try context.fetch(fetchRequest)
            // Delete the objects
            for object in objects {
                context.delete(object)
            }

            try context.save()
        } catch let error as NSError {
            // Handle the error
            print("Could not clear history: \(error), \(error.userInfo)")
        }

        numSmartCopies = 0
        numSmartCuts = 0
        numSmartPastes = 0
    }

    private func clearIntents(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<IntentEntry> = IntentEntry.fetchRequest()

        do {
            let objects = try context.fetch(fetchRequest)
            // Delete the objects
            for object in objects {
                context.delete(object)
            }

            try context.save()
        } catch let error as NSError {
            // Handle the error
            print("Could not clear intents: \(error), \(error.userInfo)")
        }
    }
}

struct HistoryListView_Previews: PreviewProvider {
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

        // Create a few sample history entries
        for i in 0..<5 {
            let entry = HistoryEntry(context: context)
            entry.id = UUID()
            entry.copiedText = "copy \(i)"
            entry.pastedResponse = "paste \(i)"
            entry.quickActionId = UUID()

            let prompt = PromptEntry(context: context)
            prompt.id = entry.quickActionId
            prompt.prompt = "prompt \(i)"

            let message = MessageEntry(context: context)
            message.id = UUID()
            message.text = "sample"

            let intent = IntentEntry(context: context)
            intent.copiedText = "copy \(i)"
            intent.prompt = "prompt \(i)"
        }

        return HistoryListView()
            .environment(\.managedObjectContext, context)
    }
}
