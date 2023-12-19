//
//  QuickAction.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import CoreData
import Foundation

enum QuickActionType: String, CaseIterable {
    case legacy = "Legacy Quick Action"
    case copyPaste = "Smart-copy, Smart-paste"
    case autopilot = "Autopilot Workflow"

    // Function to map 16-bit integer to QuickActionType using CaseIterable
    static func from(_ int: Int16) -> QuickActionType? {
        let index = Int(int)
        guard QuickActionType.allCases.indices.contains(index) else {
            return nil
        }
        return QuickActionType.allCases[index]
    }

    var int16: Int16 {
        return Int16(QuickActionType.allCases.firstIndex(of: self) ?? 0)
    }
}

struct QuickAction {
    let id: UUID
    let prompt: String
    let details: String?
    let createdAt: Date
    let quickActionType: QuickActionType
}

extension QuickAction {
    init?(from entry: PromptEntry) {
        guard let id = entry.id,
              let prompt = entry.prompt,
              let createdAt = entry.createdAt else {
            return nil
        }

        self.id = id
        self.prompt = prompt
        self.details = entry.details
        self.createdAt = createdAt
        self.quickActionType = QuickActionType.from(entry.type) ?? QuickActionType.legacy
    }

    func serialize(context: NSManagedObjectContext) -> PromptEntry {
        let entry = PromptEntry(context: context)
        entry.id = self.id
        entry.prompt = self.prompt
        entry.details = self.details
        entry.createdAt = self.createdAt
        entry.type = self.quickActionType.int16
        return entry
    }
}
