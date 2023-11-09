//
//  PromptManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import CoreData
import Foundation
import os.log

class PromptManager: ObservableObject {
    var activePromptID: UUID?
    private let context: NSManagedObjectContext

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "PromptManager"
    )

    init(context: NSManagedObjectContext) {
        self.activePromptID = nil
        self.context = context
    }

    /// Fetch prompts from Core Data
    func getPrompts() -> [PromptEntry] {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        do {
            return try context.fetch(fetchRequest)
        } catch {
            logger.error("Failed to fetch prompts: \(error)")
            return []
        }
    }

    @MainActor
    func setActivePrompt(id: UUID) {
        DispatchQueue.main.async {
            self.activePromptID = id
        }
    }

    func getActivePrompt() -> String? {
        if let activeID = activePromptID {
            let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@",
                                                 activeID as CVarArg)
            do {
                let fetchedObjects = try context.fetch(fetchRequest)
                if let promptEntry = fetchedObjects.first {
                    return promptEntry.prompt
                }
            } catch {
                // Handle the error appropriately
                logger.error("Error fetching entry: \(error.localizedDescription)")
            }
        }

        return nil
    }

    @discardableResult
    func addPrompt(_ prompt: String, details: String? = nil) -> PromptEntry? {
        let newPrompt = PromptEntry(context: context)
        newPrompt.id = UUID()
        newPrompt.prompt = prompt

        if let details = details {
            newPrompt.details = details
        } else {
            newPrompt.details = prompt
        }

        newPrompt.createdAt = Date()

        do {
            try context.save()
            self.activePromptID = newPrompt.id
            return newPrompt
        } catch {
            logger.error("Failed to save prompt: \(error)")
            return nil
        }
    }

    func getByLabel(_ label: String) -> PromptEntry? {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "prompt ==[c] %@",
                                             label as CVarArg)
        do {
            let fetchedObjects = try context.fetch(fetchRequest)
            if let promptEntry = fetchedObjects.first {
                return promptEntry
            }
        } catch {
            // Handle the error appropriately
            logger.error("Error fetching entry: \(error.localizedDescription)")
        }

        return nil
    }

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
                self.activePromptID = id
            }
        } catch {
            // Handle the error appropriately
            logger.error("Error updating entry: \(error.localizedDescription)")
        }
    }

    func removePrompt(with id: UUID) {
        if activePromptID == id {
            activePromptID = nil
        }

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
