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
        self.managedObjectContext = PersistenceController.shared.newBackgroundContext()
    }

    @discardableResult
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
            logger.debug("Created a new intent")
        } catch {
            logger.error("Failed to create new intent: \(error.localizedDescription)")
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

    func fetchIntentsAsMessages(
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

            var topPromptsString = "Most common user intents for this context:\n"
            for (prompt, count) in promptCounts.sorted(by: { $0.value > $1.value }).prefix(limit) {
                topPromptsString += "- \(prompt) (used \(count)x)\n"
            }

            return [Message(id: UUID(), text: topPromptsString, isCurrentUser: true)]
        } catch {
            logger.error("Failed to fetch history entries: \(error.localizedDescription)")
            return []
        }
    }

    func fetchContextualIntents(
        limit: Int,
        appContext: AppContext?
    ) -> [String] {
        guard let appContext = appContext else {
            return []
        }

        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "IntentEntry")
        fetchRequest.resultType = .dictionaryResultType

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

        let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "prompt")])
        let countExpressionDescription = NSExpressionDescription()
        countExpressionDescription.name = "count"
        countExpressionDescription.expression = countExpression
        countExpressionDescription.expressionResultType = .integer32AttributeType

        fetchRequest.propertiesToFetch = ["prompt", countExpressionDescription]
        fetchRequest.propertiesToGroupBy = ["prompt"]
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false)]
        fetchRequest.fetchLimit = limit

        do {
            return try managedObjectContext.performAndWait {
                let results = try managedObjectContext.fetch(fetchRequest) as? [NSDictionary]
                let intents = results?.compactMap { dict -> String? in
                    if let prompt = dict["prompt"] as? String,
                       let _ = dict["count"] as? Int {
                        return prompt
                    }
                    return nil
                }
                return intents ?? []
            }
        } catch {
            logger.error("Failed to fetch top intents: \(error.localizedDescription)")
        }

        return []
    }
}
