//
//  IntentManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/3/23.
//

import Foundation
import CoreData
import os.log

struct UserIntent: Codable {
    let copiedText: String
    let appName: String?
    let bundleIdentifier: String?
    let url: String?
}

class IntentManager {
    private let managedObjectContext: NSManagedObjectContext
    private let maxLength: Int = 1000  // Truncate each copiedText

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "IntentManager"
    )

    init(context: NSManagedObjectContext) {
        self.managedObjectContext = context
    }

    func addIntentEntry(
        prompt: String,
        copiedText: String,
        appContext: AppContext?
    ) -> IntentEntry {
        let newEntry = IntentEntry(context: managedObjectContext)
        newEntry.prompt = prompt
        newEntry.copiedText = copiedText
        newEntry.url = appContext?.url?.host
        newEntry.appName = appContext?.appName
        newEntry.bundleIdentifier = appContext?.bundleIdentifier
        newEntry.decayedScore = 1.0
        newEntry.updatedAt = Date()

        do {
            try managedObjectContext.save()
            logger.debug("Added entry")
        } catch {
            logger.error("Failed to save new history entry: \(error.localizedDescription)")
        }

        return newEntry
    }

    private func decayedScore(originalScore: Float, timestamp: Date) -> Float {
        let decayConstant: Float = 0.001 // Adjust this based on your requirements
        let currentTime = Date().timeIntervalSince1970
        let entryTime = timestamp.timeIntervalSince1970
        let deltaTime = Float(currentTime - entryTime)
        return originalScore * exp(-decayConstant * deltaTime)
    }

    func fetchIntents(
        limit: Int,
        appContext: AppContext?
    ) -> [Message] {
        guard let appContext = appContext else {
            return []
        }

        let fetchRequest: NSFetchRequest<IntentEntry> = IntentEntry.fetchRequest()
        var predicates = [NSPredicate]()

        if let url = appContext.url?.host {
            predicates.append(NSPredicate(format: "url == %@", url))
        }

        if let appName = appContext.appName {
            predicates.append(NSPredicate(format: "appName == %@", appName))
        }

        if let bundleIdentifier = appContext.bundleIdentifier {
            predicates.append(NSPredicate(format: "bundleIdentifier == %@", bundleIdentifier))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        fetchRequest.fetchLimit = 50

        do {
            let entries = try managedObjectContext.fetch(fetchRequest)

            // NOTE: Count the most common recent prompts and construct a user message
            var promptCounts = [String: Int]()
            for entry in entries {
                if let prompt = entry.prompt {
                    promptCounts[prompt] = (promptCounts[prompt] ?? 0) + 1
                }
            }

            var topPromptsString = "Most common answers for this context:\n"
            for (prompt, count) in promptCounts.sorted(by: { $0.value > $1.value }).prefix(limit) {
                topPromptsString += "- \(prompt) (used \(count)x)\n"
            }

            return [Message(id: UUID(), text: topPromptsString, isCurrentUser: true)]
        } catch {
            logger.error("Failed to fetch history entries: \(error.localizedDescription)")
            return []
        }
    }
}
