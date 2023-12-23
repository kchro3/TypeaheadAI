//
//  QuickAction.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import CoreData
import Foundation

struct QuickAction {
    let id: UUID
    let prompt: String
    let details: String?
    let createdAt: Date

    var isWebEnabled: Bool
    var isAutopilotEnabled: Bool
}

extension QuickAction {
    init?(from promptEntry: PromptEntry) {
        guard let id = promptEntry.id,
              let prompt = promptEntry.prompt,
              let createdAt = promptEntry.createdAt else {
            return nil
        }

        self.id = id
        self.prompt = prompt
        self.details = promptEntry.details
        self.createdAt = createdAt
        self.isWebEnabled = promptEntry.isWebEnabled
        self.isAutopilotEnabled = promptEntry.isAutopilotEnabled
    }
}
