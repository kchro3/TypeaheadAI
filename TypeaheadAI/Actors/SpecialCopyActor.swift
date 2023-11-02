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
    private let historyManager: HistoryManager
    private let clientManager: ClientManager
    private let promptManager: PromptManager
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
        promptManager: PromptManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.historyManager = historyManager
        self.clientManager = clientManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }
    
    func specialCopy(stickyMode: Bool) {
        self.logger.debug("special copy")

        self.appContextManager.getActiveAppInfo { appContext in
            self.simulateCopy() {
                var messageType: MessageType = .string
                guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                    return
                }

                if let htmlString = self.extractHTML(appContext: appContext) {
                    messageType = .html(data: htmlString)
                }

                // Clear the modal text and reissue request
                Task {
                    await self.modalManager.clearText(stickyMode: stickyMode)
                    await self.modalManager.showModal()
                    await NSApp.activate(ignoringOtherApps: true)

                    if let nCopies = self.numSmartCopies {
                        self.numSmartCopies = nCopies + 1
                    } else {
                        self.numSmartCopies = 1
                    }

                    Task {
                        // Set the copied text as a new message
                        await self.modalManager.setUserMessage(copiedText, messageType: messageType)

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
                            ) {
                                await self.modalManager.setUserIntents(intents: intents.intents)
                            }
                        } catch let error as ClientManagerError {
                            self.logger.error("\(error.localizedDescription)")
                            await self.modalManager.setError(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }
}
