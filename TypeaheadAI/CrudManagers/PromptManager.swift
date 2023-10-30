//
//  PromptManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import CoreData
import Foundation

class PromptManager: ObservableObject {
    @Published var savedPrompts: [PromptEntry]
    @Published var activePromptID: UUID?
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        // Fetch saved prompts from Core Data
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        do {
            self.savedPrompts = try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch prompts: \(error)")
            self.savedPrompts = []
        }
        self.activePromptID = nil
        self.context = context
    }

    func getActivePrompt() -> String? {
        if let activeID = activePromptID,
           let activePrompt = savedPrompts.first(where: { $0.id == activeID }) {
            return activePrompt.prompt
        } else {
            return nil
        }
    }

    func addPrompt(_ prompt: String, details: String? = nil) {
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
            self.savedPrompts.append(newPrompt)
            self.activePromptID = newPrompt.id
        } catch {
            print("Failed to save prompt: \(error)")
        }
    }

    func getByLabel(_ label: String) -> PromptEntry? {
        if let index = savedPrompts.firstIndex(where: { $0.prompt == label }) {
            return self.savedPrompts[index]
        } else {
            return nil
        }
    }

    func updatePrompt(with id: UUID, newLabel: String? = nil, newDetails: String? = nil) {
        if let index = savedPrompts.firstIndex(where: { $0.id == id }) {
            DispatchQueue.main.async {
                let promptToUpdate = self.savedPrompts[index]
                if let newLabel = newLabel {
                    promptToUpdate.prompt = newLabel
                }

                if let newDetails = newDetails {
                    promptToUpdate.details = newDetails
                }
                promptToUpdate.updatedAt = Date()
                do {
                    try self.context.save()
                    self.activePromptID = id
                } catch {
                    print("Failed to update prompt: \(error)")
                }
            }
        }
    }

    func removePrompt(with id: UUID) {
        if let index = savedPrompts.firstIndex(where: { $0.id == id }) {
            let promptToRemove = savedPrompts[index]
            context.delete(promptToRemove)
            do {
                try context.save()
                if activePromptID == id {
                    activePromptID = nil
                }
                self.savedPrompts.remove(at: index)
            } catch {
                print("Failed to remove prompt: \(error)")
            }
        }
    }

    func clearPrompts() {
        for entry in savedPrompts {
            context.delete(entry)
        }

        do {
            try context.save()
            self.savedPrompts.removeAll()
            self.activePromptID = nil
        } catch let error as NSError {
            print("Could not fetch or delete. \(error), \(error.userInfo)")
        }
    }
}
