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
    private let context: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let maxLength: Int = 1000  // Truncate each copiedText

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "IntentManager"
    )

    init(context: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {
        self.context = context
        self.backgroundContext = backgroundContext
    }

    @MainActor
    func addIntentEntry(
        prompt: String,
        copiedText: String,
        appContext: AppContext?
    ) {
        let newEntry = IntentEntry(context: context)
        newEntry.prompt = prompt
        newEntry.copiedText = copiedText
        newEntry.url = appContext?.url?.host
        newEntry.appName = appContext?.appName
        newEntry.bundleIdentifier = appContext?.bundleIdentifier
        newEntry.decayedScore = 1.0
        newEntry.updatedAt = Date()

        do {
            try context.save()
            logger.debug("Created a new intent")
        } catch {
            logger.error("Failed to create new intent: \(error.localizedDescription)")
        }
    }

    private func decayedScore(originalScore: Float, timestamp: Date) -> Float {
        let decayConstant: Float = 0.001 // Adjust this based on your requirements
        let currentTime = Date().timeIntervalSince1970
        let entryTime = timestamp.timeIntervalSince1970
        let deltaTime = Float(currentTime - entryTime)
        return originalScore * exp(-decayConstant * deltaTime)
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
            return try backgroundContext.performAndWait {
                let results = try backgroundContext.fetch(fetchRequest) as? [NSDictionary]
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
