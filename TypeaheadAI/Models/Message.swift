//
//  Message.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/24/23.
//

import Foundation

enum MessageType: Codable, Equatable {
    case string
    case html(data: String)
    case image(data: ImageData)
    case data(data: Data)
}

struct Conversation: Identifiable, Equatable {
    let id: UUID
    let messages: [Message]
}

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    let isCurrentUser: Bool
    let isHidden: Bool

    // Mutable because we need to scrub data when making network requests
    var appContext: AppContext?

    // Needed for rendering
    var responseError: String?
    var messageType: MessageType = .string
    var isTruncated: Bool = true
    var isEdited: Bool = false
}

extension Message {
    init?(from entry: MessageEntry) {
        guard let id = entry.id,
              let text = entry.text else {
            return nil
        }

        self.id = id
        self.text = text
        self.isCurrentUser = entry.isCurrentUser
        self.isHidden = entry.isHidden
        
        if let serializedAppContext = entry.serializedAppContext?.data(using: .utf8),
           let appContext = try? JSONDecoder().decode(AppContext.self, from: serializedAppContext) {
            self.appContext = appContext
        }

        self.responseError = entry.responseError
    }

    func serialize(conversationId: UUID) -> MessageEntry {
        let entry = MessageEntry()
        entry.id = self.id
        entry.text = self.text
        entry.conversationId = conversationId
        entry.isCurrentUser = self.isCurrentUser
        entry.isHidden = self.isHidden

        if let appContext = self.appContext,
           let data = try? JSONEncoder().encode(appContext),
           let serialized = String(data: data, encoding: .utf8) {
            entry.serializedAppContext = serialized
        }

        return entry
    }
}
