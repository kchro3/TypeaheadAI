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
    @Published var activePromptIndex: Int?

    init(context: NSManagedObjectContext) {
        // Fetch saved prompts from Core Data
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        do {
            let fetchedPrompts = try context.fetch(fetchRequest)
            self.savedPrompts = fetchedPrompts
        } catch {
            print("Failed to fetch prompts: \(error)")
            self.savedPrompts = []
        }
        self.activePromptIndex = nil
    }

    func getActivePrompt() -> String? {
        if let index = activePromptIndex {
            return savedPrompts[index].prompt
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
            self.savedPrompts.append(newPrompt)
        } catch {
            print("Failed to save prompt: \(error)")
        }
    }

    func updatePrompt(at index: Int, with newContent: String, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        do {
            let fetchedPrompts = try context.fetch(fetchRequest)
            let promptToUpdate = fetchedPrompts[index]
            promptToUpdate.prompt = newContent
            promptToUpdate.updatedAt = Date()

            try context.save()
            self.savedPrompts[index].prompt = newContent
            self.savedPrompts[index].updatedAt = Date()
        } catch {
            print("Failed to update prompt: \(error)")
        }
    }

    func removePrompt(at index: Int, context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<PromptEntry> = PromptEntry.fetchRequest()
        do {
            let fetchedPrompts = try context.fetch(fetchRequest)
            context.delete(fetchedPrompts[index])
            try context.save()
            self.savedPrompts.remove(at: index)
        } catch {
            print("Failed to remove prompt: \(error)")
        }
    }
}
