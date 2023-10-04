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
        activeUrl: String?,
        activeAppName: String?,
        activeAppBundleIdentifier: String?
    ) -> IntentEntry {
        let newEntry = IntentEntry(context: managedObjectContext)
        newEntry.prompt = prompt
        newEntry.copiedText = copiedText
        newEntry.url = activeUrl
        newEntry.appName = activeAppName
        newEntry.bundleIdentifier = activeAppBundleIdentifier
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

    func upsertIntentEntry(
        prompt: String,
        copiedText: String?,
        activeUrl: String?,
        activeAppName: String?,
        activeAppBundleIdentifier: String?
    ) {
        // Create a fetch request to find existing entries
        let fetchRequest: NSFetchRequest<IntentEntry> = IntentEntry.fetchRequest()

        var predicates = [NSPredicate]()
        predicates.append(NSPredicate(format: "prompt == %@", prompt))

        if let copiedText = copiedText {
            predicates.append(NSPredicate(format: "copiedText == %@", copiedText))
        }

        if let activeUrl = activeUrl {
            predicates.append(NSPredicate(format: "url == %@", activeUrl))
        }

        if let activeAppName = activeAppName {
            predicates.append(NSPredicate(format: "appName == %@", activeAppName))
        }

        if let activeAppBundleIdentifier = activeAppBundleIdentifier {
            predicates.append(NSPredicate(format: "bundleIdentifier == %@", activeAppBundleIdentifier))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        do {
            // Execute the fetch request
            let fetchedEntries = try managedObjectContext.fetch(fetchRequest)

            if let existingEntry = fetchedEntries.first {
                // Entry exists, update decayedScore
                existingEntry.decayedScore = decayedScore(originalScore: existingEntry.decayedScore, timestamp: existingEntry.updatedAt!)
                existingEntry.updatedAt = Date() // Update timestamp to current time

                try managedObjectContext.save() // Save the context
            } else {
                // Entry does not exist, create new one
                _ = addIntentEntry(
                    prompt: prompt,
                    copiedText: copiedText ?? "",
                    activeUrl: activeUrl,
                    activeAppName: activeAppName,
                    activeAppBundleIdentifier: activeAppBundleIdentifier
                )
            }
        } catch {
            logger.error("Failed to upsert intent entry: \(error.localizedDescription)")
        }
    }

    func fetchIntents(
        limit: Int,
        url: String? = nil,
        appName: String? = nil,
        bundleIdentifier: String? = nil
    ) -> [Message] {
        let fetchRequest: NSFetchRequest<IntentEntry> = IntentEntry.fetchRequest()
        var predicates = [NSPredicate]()

        if let url = url {
            predicates.append(NSPredicate(format: "url == %@", url))
        }

        if let appName = appName {
            predicates.append(NSPredicate(format: "appName == %@", appName))
        }

        if let bundleIdentifier = bundleIdentifier {
            predicates.append(NSPredicate(format: "bundleIdentifier == %@", bundleIdentifier))
        }

        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        fetchRequest.fetchLimit = limit

        do {
            let entries = try managedObjectContext.fetch(fetchRequest)
            var messages = [Message]()
            for entry in entries {
                guard let copiedText = entry.copiedText else {
                    continue
                }

                let intent = UserIntent(
                    copiedText: copiedText,
                    appName: entry.appName,
                    bundleIdentifier: entry.bundleIdentifier,
                    url: entry.url
                )

                if let data = try? JSONEncoder().encode(intent),
                   let serialized = String(data: data, encoding: .utf8) {
                    let userMessage = Message(id: UUID(), text: serialized, isCurrentUser: true)
                    let assistantMessage = Message(id: UUID(), text: entry.prompt!, isCurrentUser: false)
                    messages.append(contentsOf: [userMessage, assistantMessage])
                }
            }
            print(messages)
            return messages
        } catch {
            logger.error("Failed to fetch history entries: \(error.localizedDescription)")
            return []
        }
    }
}
