//
//  ConversationManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/30/23.
//

import AppKit
import CoreData
import Foundation
import SwiftUI

class ConversationManager: CanFetchAppContext {
    private let context: NSManagedObjectContext
    private var cached: [Message]?

    init(context: NSManagedObjectContext) {
        self.context = context

        try? indexFields()
        startMonitoring()
    }

    /// Index the appName, bundleIdentifier, url. Only needs to be done once.
    private func indexFields() throws {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "serializedAppContext != nil AND bundleIdentifier == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let messages = try context.fetch(fetchRequest)
        if messages.count > 0 {
            for message in messages {
                update(entry: message, with: context)
            }

            try context.save()
        }
    }

    private func update(entry: MessageEntry, with context: NSManagedObjectContext) {
        guard let serializedAppContext = entry.serializedAppContext,
              let data = serializedAppContext.data(using: .utf8),
              let appContext = try? JSONDecoder().decode(AppContext.self, from: data) else {
            return
        }

        entry.appName = appContext.appName
        entry.bundleIdentifier = appContext.bundleIdentifier
        entry.activeUrl = appContext.url?.host
    }

    private func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.saveConversationWrapper(_:)),
            name: .chatComplete,
            object: nil
        )
    }

    @MainActor
    func getConversationIds(fetchLimit: Int = 10) throws -> [UUID] {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "inReplyToId == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        fetchRequest.fetchLimit = fetchLimit

        let messages = try context.fetch(fetchRequest)
        return messages.compactMap { $0.id }
    }

    @MainActor
    func getConversations(contextual: Bool, fetchLimit: Int = 10) async throws -> [Message] {
        var predicates = [NSPredicate]()
        if contextual {
            let appContext = try await fetchAppContext()

            if let url = appContext?.url?.host {
                predicates.append(NSPredicate(format: "activeUrl == %@ || activeUrl == nil", url))
            }

            if let appName = appContext?.appName {
                predicates.append(NSPredicate(format: "appName == %@ || appName == nil", appName))
            }

            if let bundleIdentifier = appContext?.bundleIdentifier {
                predicates.append(NSPredicate(format: "bundleIdentifier == %@ || bundleIdentifier == nil", bundleIdentifier))
            }
        }

        let conversationIds = try getConversationIds(fetchLimit: fetchLimit)
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()
        predicates.append(NSPredicate(format: "inReplyToId == nil AND rootId IN %@", conversationIds))
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let messages = try context.fetch(fetchRequest)
        return messages.compactMap { Message(from: $0) }
    }

    @MainActor
    func getConversation(rootId: UUID) throws -> [Message] {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "rootId == %@", rootId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]

        let messages = try context.fetch(fetchRequest)
        return messages.compactMap { Message(from: $0) }
    }

    @MainActor
    func saveConversation(messages: [Message]) throws {
        if messages == cached {
            return
        } else {
            cached = messages
        }

        let _ = messages.map {
            $0.serialize(context: context)
        }

        print("saving...")
        try context.save()
    }

    @objc func saveConversationWrapper(_ notification: NSNotification) {
        guard let messages = notification.userInfo?["messages"] as? [Message] else { return }

        Task {
            do {
                try await saveConversation(messages: messages)
            } catch {
                print("\(error.localizedDescription)")
            }
        }
    }
}
