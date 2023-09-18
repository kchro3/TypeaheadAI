//
//  MessageManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/17/23.
//

import Foundation
import CoreData
import os.log

class MessageManager {
    private let managedObjectContext: NSManagedObjectContext

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "MessageManager"
    )

    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    func createEntry(
        text: String,
        attributed: AttributedOutput?,
        isCurrentUser: Bool,
        responseError: String?
    ) throws -> MessageEntry {
        var data: Data? = nil
        if let attributed = attributed {
            data = try serializeAttributedOutput(from: attributed)
        }

        let newEntry = MessageEntry(context: managedObjectContext)
        newEntry.id = UUID()
        newEntry.createdAt = Date()
        newEntry.text = text
        newEntry.attributed = data
        newEntry.isCurrentUser = isCurrentUser
        newEntry.responseError = responseError

        try managedObjectContext.save()
        return newEntry
    }

    private func serializeAttributedOutput(from output: AttributedOutput) throws -> Data {
        return try JSONEncoder().encode(output)
    }
}
