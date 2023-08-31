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
    }

    func getActivePrompt() -> String? {
        if let activeID = activePromptID,
           let activePrompt = savedPrompts.first(where: { $0.id == activeID }) {
            return activePrompt.prompt
        } else {
            return nil
        }
    }

    func addPrompt(_ prompt: String, context: NSManagedObjectContext) {
        let newPrompt = PromptEntry(context: context)
        newPrompt.id = UUID()
        newPrompt.prompt = prompt
        newPrompt.createdAt = Date()

        do {
            try context.save()
            self.savedPrompts.insert(newPrompt, at: 0)
            self.activePromptID = newPrompt.id
        } catch {
            print("Failed to save prompt: \(error)")
        }
    }

    func updatePrompt(with id: UUID, newContent: String, context: NSManagedObjectContext) {
        if let index = savedPrompts.firstIndex(where: { $0.id == id }) {
            let promptToUpdate = savedPrompts[index]
            promptToUpdate.prompt = newContent
            promptToUpdate.updatedAt = Date()
            do {
                try context.save()
                self.activePromptID = id
            } catch {
                print("Failed to update prompt: \(error)")
            }
        }
    }

    func removePrompt(with id: UUID, context: NSManagedObjectContext) {
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

    func clearPrompts(context: NSManagedObjectContext) {
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
