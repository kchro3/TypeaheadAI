//
//  HistoryManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import Foundation
import CoreData
import os.log

/// The HistoryManager handles reads and writes to the underlying CoreData.
/// The History domain model is required for thread-safety.
class HistoryManager {
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "HistoryManager"
    )

    init(context: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {
        self.context = context
        self.backgroundContext = backgroundContext
    }

    // TODO: context other input/output types
    @MainActor
    func addHistoryEntry(
        copiedText: String,
        pastedResponse: String,
        quickActionId: UUID?,
        activeUrl: String?,
        activeAppName: String?,
        activeAppBundleIdentifier: String?,
        numMessages: Int
    ) {
        let newEntry = HistoryEntry(context: context)
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
            try context.save()
            logger.debug("Added entry")
        } catch {
            logger.error("Failed to save new history entry: \(error.localizedDescription)")
        }
    }

    func fetchHistoryEntriesAsMessages(
        limit: Int,
        appContext: AppContext?,
        quickActionID: UUID? = nil
    ) -> [Message] {
        guard let appContext = appContext else {
            return []
        }

        let fetchRequest: NSFetchRequest<HistoryEntry> = HistoryEntry.fetchRequest()
        var predicates = [NSPredicate]()

        if let quickActionID = quickActionID {
            predicates.append(NSPredicate(format: "quickActionId == %@", quickActionID as CVarArg))
        }

        if let url = appContext.url?.host {
            predicates.append(NSPredicate(format: "activeUrl == %@ || activeUrl == nil", url))
        }

        if let appName = appContext.appName {
            predicates.append(NSPredicate(format: "activeAppName == %@ || activeAppName == nil", appName))
        }

        if let bundleIdentifier = appContext.bundleIdentifier {
            predicates.append(NSPredicate(format: "activeAppBundleIdentifier == %@ || activeAppBundleIdentifier == nil", bundleIdentifier))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = limit

        do {
            return try backgroundContext.performAndWait {
                let entries = try backgroundContext.fetch(fetchRequest)
                var messages = [Message]()
                for entry in entries {
                    let userMessage = Message(id: entry.id!, rootId: entry.id!, inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: entry.copiedText!, isCurrentUser: true, isHidden: false, appContext: appContext)
                    let assistantMessage = Message(id: entry.id!, rootId: entry.id!, inReplyToId: nil, createdAt: Date(), rootCreatedAt: Date(), text: entry.pastedResponse!, isCurrentUser: false, isHidden: false, appContext: appContext)
                    messages.append(contentsOf: [userMessage, assistantMessage])
                }
                return messages
            }
        } catch {
            logger.error("Failed to fetch history entries: \(error.localizedDescription)")
            return []
        }
    }
}
