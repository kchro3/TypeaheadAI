//
//  ConversationManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/30/23.
//

import AppKit
import CoreData
import Foundation

class ConversationManager {
    private let context: NSManagedObjectContext
    private var cached: [Message]?

    init(context: NSManagedObjectContext) {
        self.context = context
        startMonitoring()
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
    func getConversationIds() throws -> [UUID] {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "inReplyToId == nil")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let messages = try context.fetch(fetchRequest)
        return messages.compactMap { $0.id }
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
