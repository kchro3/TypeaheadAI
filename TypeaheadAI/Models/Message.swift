//
//  Message.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/24/23.
//

import AppKit
import Foundation

/// NOTE: Add a message context for smart-copy
enum MessageContext: Codable, Equatable {
    case focus
}

enum MessageType: Codable, Equatable {
    case string
    case html(data: String)
    case markdown(data: String)
    case image(data: ImageData)
    case data(data: Data)
    case function_call(data: [FunctionCall])
    case tool_call(data: FunctionCall)
}

struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    let rootId: UUID
    let inReplyToId: UUID?
    let createdAt: Date
    let rootCreatedAt: Date

    var text: String
    let isCurrentUser: Bool
    let isHidden: Bool
    let quickActionId: UUID?

    // Mutable because we need to scrub data when making network requests
    var appContext: AppContext?

    // Needed for rendering
    var responseError: String?
    var messageType: MessageType = .string
    var isTruncated: Bool = true
    var isEdited: Bool = false
    var messageContext: MessageContext? = nil

    init(
        id: UUID,
        rootId: UUID,
        inReplyToId: UUID?,
        createdAt: Date,
        rootCreatedAt: Date,
        text: String,
        isCurrentUser: Bool,
        isHidden: Bool,
        quickActionId: UUID? = nil,
        appContext: AppContext? = nil,
        responseError: String? = nil,
        messageType: MessageType = .string,
        isTruncated: Bool = true,
        isEdited: Bool = false,
        messageContext: MessageContext? = nil
    ) {
        self.id = id
        self.rootId = rootId
        self.inReplyToId = inReplyToId
        self.createdAt = createdAt
        self.rootCreatedAt = rootCreatedAt
        self.text = text
        self.isCurrentUser = isCurrentUser
        self.isHidden = isHidden
        self.appContext = appContext
        self.responseError = responseError
        self.messageType = messageType
        self.isTruncated = isTruncated
        self.isEdited = isEdited
        self.quickActionId = quickActionId
        self.messageContext = messageContext
    }
}

extension Message {
    init?(from entry: MessageEntry) {
        guard let id = entry.id,
              let rootId = entry.rootId,
              let text = entry.text,
              let createdAt = entry.createdAt,
              let rootCreatedAt = entry.rootCreatedAt else {
            return nil
        }

        self.id = id
        self.rootId = rootId
        self.inReplyToId = entry.inReplyToId
        self.createdAt = createdAt
        self.rootCreatedAt = rootCreatedAt

        self.text = text
        self.isCurrentUser = entry.isCurrentUser
        self.isHidden = entry.isHidden
        self.quickActionId = entry.quickActionId

        if let serialized = entry.serializedMessageType?.data(using: .utf8),
           let messageType = try? JSONDecoder().decode(MessageType.self, from: serialized) {
            self.messageType = messageType
        }

        if let serialized = entry.serializedAppContext?.data(using: .utf8),
           let appContext = try? JSONDecoder().decode(AppContext.self, from: serialized) {
            self.appContext = appContext
        }

        if let serialized = entry.serializedMessageContext?.data(using: .utf8),
           let messageContext = try? JSONDecoder().decode(MessageContext.self, from: serialized) {
            self.messageContext = messageContext
        }

        self.responseError = entry.responseError
    }

    func serialize(context: NSManagedObjectContext) -> MessageEntry {
        let entry = MessageEntry(context: context)
        entry.id = self.id
        entry.rootId = self.rootId
        entry.inReplyToId = self.inReplyToId
        entry.createdAt = self.createdAt
        entry.rootCreatedAt = self.rootCreatedAt
        entry.text = self.text
        entry.isCurrentUser = self.isCurrentUser
        entry.isHidden = self.isHidden
        entry.quickActionId = self.quickActionId

        switch self.messageType {
        case .image(.b64Json(_)):
            if let data = try? JSONEncoder().encode(MessageType.string),
               let serialized = String(data: data, encoding: .utf8) {
                entry.serializedMessageType = serialized
                entry.text = NSLocalizedString("<Error: Images are not saved to history>", comment: "")
            }
        default:
            if let data = try? JSONEncoder().encode(self.messageType),
               let serialized = String(data: data, encoding: .utf8) {
                entry.serializedMessageType = serialized
            }
        }

        if let messageContext = self.messageContext,
           let data = try? JSONEncoder().encode(messageContext),
           let serialized = String(data: data, encoding: .utf8) {
            entry.serializedMessageContext = serialized
        }

        if let appContext = self.appContext,
           let data = try? JSONEncoder().encode(appContext),
           let serialized = String(data: data, encoding: .utf8) {
            entry.serializedAppContext = serialized

            // Indexable fields
            entry.appName = appContext.appName
            entry.bundleIdentifier = appContext.bundleIdentifier
            entry.activeUrl = appContext.url?.host
        }

        return entry
    }
}
