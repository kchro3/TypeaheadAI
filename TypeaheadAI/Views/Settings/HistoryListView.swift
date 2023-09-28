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

    @State private var showAlert = false

    @AppStorage("numSmartCopies") var numSmartCopies: Int?
    @AppStorage("numSmartPastes") var numSmartPastes: Int?
    @AppStorage("numSmartCuts") var numSmartCuts: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("History").font(.title)

            Text("Smart-paste function is a powerful feedback mechanism because you are implicitly telling TypeaheadAI how you like things to be done. Everyone is different, so the more you smart-copy and smart-paste, the better TypeaheadAI will be at predicting what you want and how you want it.")
            Text("You can view and manage your history here.")

            Divider()

            HStack {
                Text("^[\(numSmartCopies ?? 0) smart-copy](inflect: true)")
                Text("^[\(numSmartCuts ?? 0) smart-cut](inflect: true)")
                Text("^[\(numSmartPastes ?? 0) smart-paste](inflect: true)")
            }

            Table(history) {
                TableColumn("Date") { entry in
                    Text(entry.timestamp?.formatted() ?? "unknown")
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

            Divider()

            Button("Clear History") {
                showAlert = true
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Confirm clearing history"),
                    message: Text("Are you sure you want to the history? This action cannot be undone."),
                    primaryButton: .destructive(Text("Clear")) {
                        clearHistory(context: managedObjectContext)
                    },
                    secondaryButton: .cancel()
                )
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

        numSmartCopies = 0
        numSmartCuts = 0
        numSmartPastes = 0
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
