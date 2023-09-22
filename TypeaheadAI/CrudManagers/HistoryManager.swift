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

    // TODO: add context
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
}
