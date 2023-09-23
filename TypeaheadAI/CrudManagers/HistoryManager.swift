//
//  HistoryManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import Foundation
import CoreData
import os.log

class HistoryManager {
    private let managedObjectContext: NSManagedObjectContext

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "HistoryManager"
    )

    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    // TODO: context other input/output types
    func addHistoryEntry(
        copiedText: String,
        pastedResponse: String,
        quickActionId: UUID?,
        activeUrl: String?,
        activeAppName: String?,
        activeAppBundleIdentifier: String?,
        numMessages: Int
    ) -> HistoryEntry {
        let newEntry = HistoryEntry(context: managedObjectContext)
        newEntry.id = UUID()
        newEntry.timestamp = Date()
        newEntry.quickActionId = quickActionId
        newEntry.copiedText = copiedText
        newEntry.pastedResponse = pastedResponse
        newEntry.activeUrl = activeUrl
        newEntry.activeAppName = activeAppName
        newEntry.activeAppBundleIdentifier = activeAppBundleIdentifier
        newEntry.numMessages = Int16(numMessages)

        do {
            try managedObjectContext.save()
            logger.debug("Added entry")
        } catch {
            logger.error("Failed to save new history entry: \(error.localizedDescription)")
        }

        return newEntry
    }

    func fetchHistoryEntries(
        limit: Int,
        quickActionId: UUID? = nil,
        activeUrl: String? = nil,
        activeAppName: String? = nil,
        activeAppBundleIdentifier: String? = nil
    ) -> [Message] {
        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        var predicates = [NSPredicate]()

        if let quickActionId = quickActionId {
            predicates.append(NSPredicate(format: "quickActionId == %@", quickActionId as CVarArg))
        }

        if let activeUrl = activeUrl {
            predicates.append(NSPredicate(format: "activeUrl == %@", activeUrl))
        }

        if let activeAppName = activeAppName {
            predicates.append(NSPredicate(format: "activeAppName == %@", activeAppName))
        }

        if let activeAppBundleIdentifier = activeAppBundleIdentifier {
            predicates.append(NSPredicate(format: "activeAppBundleIdentifier == %@", activeAppBundleIdentifier))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "numMessages", ascending: true)]
        fetchRequest.fetchLimit = limit

        do {
            let entries = try managedObjectContext.fetch(fetchRequest)
            var messages = [Message]()
            for entry in entries {
                let userMessage = Message(id: entry.id!, text: entry.copiedText!, isCurrentUser: true)
                let assistantMessage = Message(id: entry.id!, text: entry.pastedResponse!, isCurrentUser: false)
                messages.append(contentsOf: [userMessage, assistantMessage])
            }
            return messages
        } catch {
            logger.error("Failed to fetch history entries: \(error.localizedDescription)")
            return []
        }
    }
}
