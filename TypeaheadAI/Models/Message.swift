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

// TODO: Add to persistence
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
