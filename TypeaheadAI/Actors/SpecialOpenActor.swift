//
//  SpecialOpenActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/5/23.
//

import AppKit
import Foundation
import os.log

actor SpecialOpenActor: CanPerformOCR {
    private let clientManager: ClientManager
    private let promptManager: QuickActionManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialOpenActor"
    )

    init(
        clientManager: ClientManager,
        promptManager: QuickActionManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.clientManager = clientManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }

    func specialOpen(forceRefresh: Bool = false) async throws {
        var appContext = try await self.appContextManager.getActiveAppInfo()
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

        if self.modalManager.messages.isEmpty {
            // Set the OCR'ed text
            if let screenshot = appContext?.screenshotPath.flatMap({ NSImage(contentsOfFile: $0)?.toCGImage() }) {
                let (ocrText, _) = try await performOCR(image: screenshot)
                appContext?.ocrText = ocrText
            }

            // Try to predict the user intent
            do {
                if let intents = try await self.clientManager.suggestIntents(
                    id: UUID(),
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: nil,
                    userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                    userLang: Locale.preferredLanguages.first ?? "",
                    copiedText: "",
                    messages: self.modalManager.messages,
                    history: [],
                    appContext: appContext,
                    incognitoMode: !self.modalManager.online
                ) {
                    await self.modalManager.setUserIntents(intents: intents.intents)
                }
            } catch {
                self.logger.error("\(error.localizedDescription)")
                await self.modalManager.setError(error.localizedDescription)
            }
        }
    }
}
