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

actor SpecialOpenActor: CanGetUIElements {
    private let intentManager: IntentManager
    private let clientManager: ClientManager
    private let promptManager: QuickActionManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

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
        var appInfo = try await self.appContextManager.getActiveAppInfo()

        if forceRefresh {
            self.logger.debug("special new")
            await self.modalManager.forceRefresh()
            await self.modalManager.showModal()
            await NSApp.activate(ignoringOtherApps: true)
        } else {
            self.logger.debug("special open")
            if await self.modalManager.isWindowVisible() {
                // EARLY RETURN!
                await self.modalManager.closeModal()
                return
            } else {
                await self.modalManager.showModal()
                await NSApp.activate(ignoringOtherApps: true)
            }
        }

        if self.modalManager.messages.isEmpty && (self.modalManager.userIntents?.isEmpty ?? true) {
            // Try to predict the user intent
            let contextualIntents = self.intentManager.fetchContextualIntents(limit: 3, appContext: appInfo.appContext)
            await self.modalManager.setUserIntents(intents: contextualIntents)

            // Kick off async
            Task {
                // Serialize the UIElement
                let (uiElement, elementMap) = getUIElements(appContext: appInfo.appContext)
                if let serializedUIElement = uiElement?.serialize() {
                    print(serializedUIElement)

                    appInfo.appContext?.serializedUIElement = serializedUIElement
                    appInfo.elementMap = elementMap
                }

                if let intents = try await self.clientManager.suggestIntents(
                    id: UUID(),
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: self.modalManager.getQuickAction()?.prompt,
                    userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                    userLang: Locale.preferredLanguages.first ?? "",
                    copiedText: "",
                    messages: self.modalManager.messages,
                    history: [],
                    appContext: appInfo.appContext
                ), !intents.intents.isEmpty {
                    await self.modalManager.appendUserIntents(intents: intents.intents)
                }
            }
        }
    }
}
