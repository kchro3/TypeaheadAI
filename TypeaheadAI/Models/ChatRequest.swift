//
//  ChatRequest.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 2/13/24.
//

import Foundation

struct ChatRequest: Codable {
    let uuid: UUID
    var username: String
    var userFullName: String
    var userObjective: String?
    var userBio: String?
    var userLang: String?
    var copiedText: String?
    var messages: [Message]
    var history: [Message]?
    var appContext: AppContext?
    var version: String
    var isAutopilotEnabled: Bool?
    var apps: [String]?
    var isVoiceOverEnabled: Bool?
    var clientVersion: String?
}
