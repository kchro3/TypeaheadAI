//
//  SmartClickActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/21/23.
//

import AppKit
import Foundation
import os.log

actor SmartClickActor: CanPerformOCR, CanSimulateCopy {
    private let intentManager: IntentManager
    private let clientManager: ClientManager
    private let promptManager: QuickActionManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager
    private let contextWindowManager: ContextWindowManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SmartClickActor"
    )

    init(
        intentManager: IntentManager,
        clientManager: ClientManager,
        promptManager: QuickActionManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager,
        contextWindowManager: ContextWindowManager
    ) {
        self.intentManager = intentManager
        self.clientManager = clientManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
        self.contextWindowManager = contextWindowManager
    }

    func smartClick() async throws {
        var appContext = try await self.appContextManager.getActiveAppInfo()

        do {
            try await simulateCopy()
            copiedText = NSPasteboard.general.string(forType: .string)
        } catch {
            // no-op: if nothing was copied, then don't do anything
        }

        // Set the copied text as a new message
        if let copiedText = copiedText {
            await self.modalManager.setUserMessage(copiedText, messageType: .string)
        }

        // Set the OCR'ed text
        if let screenshot = appContext?.screenshotPath.flatMap({ NSImage(contentsOfFile: $0)?.toCGImage() }) {
            let (ocrText, _) = try await performOCR(image: screenshot)
            appContext?.ocrText = ocrText
        }

        // Try to predict the user intent
        let contextualIntents = self.intentManager.fetchContextualIntents(limit: 3, appContext: appContext)
        await self.modalManager.setUserIntents(intents: contextualIntents)

        // Kick off async
        Task {
            // Set the OCR'ed text
            if let screenshot = appContext?.screenshotPath.flatMap({
                NSImage(contentsOfFile: $0)?.toCGImage()
            }) {
                let (ocrText, _) = try await performOCR(image: screenshot)
                appContext?.ocrText = ocrText
            }

            if let intents = try await self.clientManager.suggestIntents(
                id: UUID(),
                username: NSUserName(),
                userFullName: NSFullUserName(),
                userObjective: self.promptManager.getActivePrompt(),
                userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                userLang: Locale.preferredLanguages.first ?? "",
                copiedText: copiedText,
                messages: self.modalManager.messages,
                history: [],
                appContext: appContext,
                incognitoMode: !self.modalManager.online
            ), !intents.intents.isEmpty {
                await self.modalManager.appendUserIntents(intents: intents.intents)
            }
        }
    }
}
