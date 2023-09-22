//
//  HistoryListView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import SwiftUI
import CoreData

struct HistoryListView: View {
    @Environment(\.managedObjectContext) var managedObjectContext
    @FetchRequest(entity: HistoryEntry.entity(), sortDescriptors: []) var history: FetchedResults<HistoryEntry>
    @FetchRequest(entity: PromptEntry.entity(), sortDescriptors: []) var quickActions: FetchedResults<PromptEntry>

    var body: some View {
        VStack {
            Text("WIP: This will look nice later...")

            List {
                ForEach(history, id: \.self) { history in
                    LazyVStack(alignment: .leading) {
                        Text("Timestamp: \(history.timestamp ?? Date())")
                        Text("Pasted Response: \(history.pastedResponse ?? "")")
                        Text("Num Messages: \(history.numMessages)")
                        Text("ID: \(history.id ?? UUID())")
                        Text("Copied Text: \(history.copiedText ?? "")")
                        Text("Active URL: \(history.activeUrl ?? "")")
                        Text("Active App Name: \(history.activeAppName ?? "")")
                        Text("Active App Bundle Identifier: \(history.activeAppBundleIdentifier ?? "")")

                        let quickActionId = history.quickActionId
                        let quickAction = quickActions.first(where: { $0.id == quickActionId })
                        Text("Quick Action Name: \(quickAction?.prompt ?? "")")
                    }
                }
            }
            .frame(maxHeight: 300)
            .cornerRadius(15)

            Divider()

            Button("Clear History") {
                clearHistory(context: managedObjectContext)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
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
        }

        return HistoryListView()
            .environment(\.managedObjectContext, context)
    }
}
