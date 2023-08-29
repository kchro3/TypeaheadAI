//
//  HistoryManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/29/23.
//

import Foundation
import CoreData
import os.log

enum RequestStatus: String {
    case pending, success, failure
}

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
    func addHistoryEntry(query: String) -> HistoryEntry {
        let newEntry = HistoryEntry(context: managedObjectContext)
        newEntry.id = UUID()
        newEntry.query = query
        newEntry.timestamp = Date()
        newEntry.status = RequestStatus.pending.rawValue

        do {
            try managedObjectContext.save()
        } catch {
            logger.error("Failed to save new history entry: \(error.localizedDescription)")
        }

        return newEntry
    }

    func updateHistoryEntry(entry: HistoryEntry, withResponse response: String?, andStatus status: RequestStatus) {
        entry.response = response
        entry.status = status.rawValue

        do {
            try managedObjectContext.save()
        } catch {
            logger.error("Failed to update history entry: \(error.localizedDescription)")
        }
    }
}
