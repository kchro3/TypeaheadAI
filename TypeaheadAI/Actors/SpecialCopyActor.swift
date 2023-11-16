//
//  SpecialCopyActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/10/23.
//

import Foundation
import SwiftUI
import os.log

actor SpecialCopyActor: CanSimulateCopy, CanPerformOCR {
    private let historyManager: HistoryManager
    private let clientManager: ClientManager
    private let promptManager: QuickActionManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    @AppStorage("numSmartCopies") var numSmartCopies: Int?

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCopyActor"
    )

    init(
        historyManager: HistoryManager,
        clientManager: ClientManager,
        promptManager: QuickActionManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.historyManager = historyManager
        self.clientManager = clientManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }
    
    func specialCopy() async throws {
        var appContext = try await self.appContextManager.getActiveAppInfo()
        try await self.simulateCopy()

        // Clear the current state
        await promptManager.setActivePrompt(id: nil)
        await self.modalManager.forceRefresh()
        await self.modalManager.showModal()
        await NSApp.activate(ignoringOtherApps: true)

        var messageType: MessageType = .string
        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            return
        }

        if let htmlString = self.extractHTML(appContext: appContext) {
            messageType = .html(data: htmlString)
        }

        if let nCopies = self.numSmartCopies {
            self.numSmartCopies = nCopies + 1
        } else {
            self.numSmartCopies = 1
        }

        // Set the copied text as a new message
        await self.modalManager.setUserMessage(copiedText, messageType: messageType)

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
                userObjective: self.promptManager.getActivePrompt(),
                userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                userLang: Locale.preferredLanguages.first ?? "",
                copiedText: copiedText,
                messages: self.modalManager.messages,
                history: [],
                appContext: appContext,
                incognitoMode: !self.modalManager.online
            ), !intents.intents.isEmpty {
                await self.modalManager.setUserIntents(intents: intents.intents)
            } else {
                await self.modalManager.replyToUserMessage(refresh: false)
            }
        } catch {
            self.logger.error("\(error.localizedDescription)")
            await self.modalManager.setError(error.localizedDescription)
        }
    }
}
