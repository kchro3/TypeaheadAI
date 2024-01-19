//
//  SpecialCopyActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/10/23.
//

import Foundation
import SwiftUI
import os.log

actor SpecialCopyActor: CanSimulateCopy {
    private let intentManager: IntentManager
    private let historyManager: HistoryManager
    private let clientManager: ClientManager
    private let promptManager: QuickActionManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    @AppStorage("numSmartCopies") var numSmartCopies: Int?
    @AppStorage("isAutopilotEnabled") private var isAutopilotEnabled: Bool = true

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCopyActor"
    )

    init(
        intentManager: IntentManager,
        historyManager: HistoryManager,
        clientManager: ClientManager,
        promptManager: QuickActionManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.intentManager = intentManager
        self.historyManager = historyManager
        self.clientManager = clientManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }
    
    func specialCopy() async throws {
        let appInfo = try await self.appContextManager.getActiveAppInfo()
        try await self.simulateCopy()

        // Clear the current state
        await self.modalManager.forceRefresh()

        var messageType: MessageType = .string
        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            return
        }

        if let markdownString = try? getMarkdownFromPasteboard() {
            messageType = .markdown(data: markdownString)
        }

        if let nCopies = self.numSmartCopies {
            self.numSmartCopies = nCopies + 1
        } else {
            self.numSmartCopies = 1
        }

        // Set the copied text as a new message
        await self.modalManager.setUserMessage("Smart-copied:\n\n\(copiedText)", messageType: messageType, appContext: appInfo.appContext)

        // Try to predict the user intent
        let contextualIntents = self.intentManager.fetchContextualIntents(limit: 10, appContext: appInfo.appContext)
        await self.modalManager.setUserIntents(intents: contextualIntents)

        try await self.modalManager.prepareUserInput()
    }
}
