//
//  SpecialOpenActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/5/23.
//

import AppKit
import CoreServices
import Foundation
import os.log
import SwiftUI

actor SpecialOpenActor {
    private let intentManager: IntentManager
    private let clientManager: ClientManager
    private let promptManager: QuickActionManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    @AppStorage("isAutopilotEnabled") private var isAutopilotEnabled: Bool = true

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialOpenActor"
    )

    init(
        intentManager: IntentManager,
        clientManager: ClientManager,
        promptManager: QuickActionManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.intentManager = intentManager
        self.clientManager = clientManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }

    func specialOpen(forceRefresh: Bool = false) async throws {
        let appInfo = try await self.appContextManager.getActiveAppInfo()

        if forceRefresh {
            self.logger.debug("special new")
            await self.modalManager.forceRefresh()
            try await self.modalManager.prepareUserInput()
        } else {
            self.logger.debug("special open")
            if await self.modalManager.isWindowVisible() {
                // EARLY RETURN!
                await self.modalManager.closeModal()
                return
            } else {
                try await self.modalManager.prepareUserInput()
            }
        }

        if self.modalManager.messages.isEmpty && (self.modalManager.userIntents?.isEmpty ?? true) {
            // Try to predict the user intent
            let contextualIntents = self.intentManager.fetchContextualIntents(limit: 3, appContext: appInfo.appContext)
            await self.modalManager.setUserIntents(intents: contextualIntents)
        }
    }
}
