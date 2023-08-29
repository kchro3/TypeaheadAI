//
//  HistoryListView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import SwiftUI
import CoreData

struct HistoryListItemView: View {
    @State var entry: HistoryEntry

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(entry.timestamp!.description(with: .autoupdatingCurrent))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Text("Objective: \(entry.objective ?? "None")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .textSelection(.enabled)
                Text(entry.query!)
                    .font(.headline)
                    .fontWeight(.bold)
                    .textSelection(.enabled)

                switch entry.status {
                case RequestStatus.failure.rawValue:
                    Text("Paste: Failed").foregroundColor(.red)
                case RequestStatus.pending.rawValue:
                    Text("Paste: Pending").foregroundColor(.yellow)
                default:
                    Text(entry.response!)
                        .textSelection(.enabled)
                }
            }
            Spacer()
        }
    }
}

struct HistoryListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \HistoryEntry.timestamp, ascending: false)],
        animation: .default
    )
    private var historyEntries: FetchedResults<HistoryEntry>

    var body: some View {
        VStack(alignment: .leading) {
            Text("History").font(.headline)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(historyEntries, id: \.id) { entry in
                        HistoryListItemView(entry: entry)
                            .padding(10)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 300)
            .cornerRadius(15)

            Divider()

            Button("Clear History") {
                clearHistory(context: viewContext)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    private func clearHistory(context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = HistoryEntry.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
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
            entry.query = "Query \(i)"
            entry.response = "Response \(i)"
            entry.timestamp = Date()
            entry.status = RequestStatus.success.rawValue
        }

        let pendingEntry = HistoryEntry(context: context)
        pendingEntry.id = UUID()
        pendingEntry.query = "Query waiting"
        pendingEntry.timestamp = Date()
        pendingEntry.status = RequestStatus.pending.rawValue

        let failedEntry = HistoryEntry(context: context)
        failedEntry.id = UUID()
        failedEntry.query = "Query bad"
        failedEntry.timestamp = Date()
        failedEntry.status = RequestStatus.failure.rawValue

        return HistoryListView()
            .environment(\.managedObjectContext, context)
    }
}
