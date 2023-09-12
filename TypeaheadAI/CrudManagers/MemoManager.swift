//
//  MemoManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/12/23.
//

import Foundation
import CoreData
import os.log

class MemoManager {
    private let managedObjectContext: NSManagedObjectContext

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "MemoManager"
    )

    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    func createEntry(summary: String, content: String) -> MemoEntry {
        let newEntry = MemoEntry(context: managedObjectContext)
        newEntry.id = UUID()
        newEntry.content = content
        newEntry.summary = summary
        newEntry.createdAt = Date()

        do {
            try managedObjectContext.save()
            logger.debug("Added memo")
        } catch {
            logger.error("Failed to save new memo: \(error.localizedDescription)")
        }

        return newEntry
    }

    func updateEntry(entry: MemoEntry, withSummary summary: String) {
        entry.summary = summary

        do {
            try managedObjectContext.save()
            logger.debug("Updated memo")
        } catch {
            logger.error("Failed to update memo: \(error.localizedDescription)")
        }
    }
}
