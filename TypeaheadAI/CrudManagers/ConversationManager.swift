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

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    @MainActor
    func getConversation(conversationId: UUID) throws -> Conversation {
        let fetchRequest: NSFetchRequest<MessageEntry> = MessageEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "conversationId == %@", conversationId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        let messages = try context.fetch(fetchRequest)
        return Conversation(
            id: conversationId,
            messages: messages.compactMap { Message(from: $0) }
        )
    }

    @MainActor
    func startConversation() throws -> UUID {
        let conversationEntry = ConversationEntry()
        let conversationId = UUID()
        conversationEntry.id = conversationId
        conversationEntry.createdAt = Date()
        
        try context.save()
        return conversationId
    }

    @MainActor
    func saveConversation(conversationId: UUID, messages: [Message]) throws {
        let messageEntries = messages.map {
            $0.serialize(conversationId: conversationId)
        }

        try context.save()
    }
}
