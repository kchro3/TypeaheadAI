//
//  PresetsManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/22/23.
//

import Foundation

class PresetsManager: ObservableObject {
    @Published var savedPrompts: [String]
    @Published var activePromptIndex: Int?
    
    init(savedPrompts: [String] = [], activePromptIndex: Int? = nil) {
        self.savedPrompts = savedPrompts
        self.activePromptIndex = activePromptIndex
    }
    
    func getActivePrompt() -> String? {
        if let index = activePromptIndex {
            return savedPrompts[index]
        } else {
            return nil
        }
    }
}
