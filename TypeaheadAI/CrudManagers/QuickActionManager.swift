//
//  QuickActionManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import CoreData
import Foundation
import os.log
import SwiftUI

/// The QuickActionManager handles reads and writes to the underlying CoreData.
/// We originally called them PromptEntry, but we unmarshal them into QuickAction structs.
/// The renaming is unfortunate, but the domain model is required for thread-safety.
class QuickActionManager: ObservableObject {
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    @AppStorage("isHistoryEnabled") private var isHistoryEnabled: Bool = true

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "PromptManager"
    )

    init(context: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {
        self.context = context
        self.backgroundContext = backgroundContext
    }

    /// Fetch prompts from Core Data
    func getPrompts() -> [String] {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        do {
            return try backgroundContext.performAndWait {
                return try backgroundContext.fetch(fetchRequest).compactMap { $0.prompt }
            }
        } catch {
            logger.error("Failed to fetch prompts: \(error)")
            return []
        }
    }

    @discardableResult
    @MainActor
    func addPrompt(_ prompt: String, id: UUID? = nil, details: String? = nil) -> QuickAction? {
        let newPrompt = PromptEntry(context: context)
        newPrompt.id = id ?? UUID()
        newPrompt.prompt = prompt
        newPrompt.details = details ?? prompt
        newPrompt.createdAt = Date()

        do {
            try context.save()
            return QuickAction(from: newPrompt)
        } catch {
            logger.error("Failed to save prompt: \(error)")
            return nil
        }
    }

    func getById(_ id: UUID) -> QuickAction? {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@",
                                             id as CVarArg)
        do {
            return try backgroundContext.performAndWait {
                let fetchedObjects = try backgroundContext.fetch(fetchRequest)
                if let promptEntry = fetchedObjects.first {
                    return QuickAction(from: promptEntry)
                } else {
                    return nil
                }
            }
        } catch {
            // Handle the error appropriately
            logger.error("Error fetching entry: \(error.localizedDescription)")
        }

        return nil
    }

    func getByLabel(_ label: String) -> QuickAction? {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "prompt ==[c] %@",
                                             label as CVarArg)
        do {
            return try backgroundContext.performAndWait {
                let fetchedObjects = try backgroundContext.fetch(fetchRequest)
                if let promptEntry = fetchedObjects.first {
                    return QuickAction(from: promptEntry)
                } else {
                    return nil
                }
            }
        } catch {
            // Handle the error appropriately
            logger.error("Error fetching entry: \(error.localizedDescription)")
        }

        return nil
    }

    func getOrCreateByLabel(_ label: String) async -> QuickAction? {
        if let quickAction = getByLabel(label) {
            return quickAction
        } else if !isHistoryEnabled {
            // Don't implicitly create a Quick Action if the history is not kept
            return nil
        } else {
            return await addPrompt(label)
        }
    }

    @MainActor
    func updatePrompt(with id: UUID, newLabel: String? = nil, newDetails: String? = nil) {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@",
                                             id as CVarArg)
        do {
            let fetchedObjects = try context.fetch(fetchRequest)
            if let promptEntry = fetchedObjects.first {
                if let label = newLabel {
                    promptEntry.prompt = label
                }
                if let details = newDetails {
                    promptEntry.details = details
                }

                promptEntry.updatedAt = Date()

                try context.save()
            }
        } catch {
            // Handle the error appropriately
            logger.error("Error updating entry: \(error.localizedDescription)")
        }
    }

    @MainActor
    func removePrompt(with id: UUID) {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@",
                                             id as CVarArg)
        do {
            let fetchedObjects = try context.fetch(fetchRequest)
            if let object = fetchedObjects.first {
                context.delete(object)
                try context.save()
            }
        } catch {
            logger.error("Error deleting entry: \(error.localizedDescription)")
        }
    }

    @MainActor
    func clearPrompts() {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()

        do {
            let objects = try context.fetch(fetchRequest)
            // Delete the objects
            for object in objects {
                context.delete(object)
            }

            try context.save()
        } catch {
            // Handle the error
            logger.error("Could not clear intents: \(error.localizedDescription)")
        }
    }
}
