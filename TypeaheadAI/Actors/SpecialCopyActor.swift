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
    
    func specialCopy(incognitoMode: Bool, stickyMode: Bool) {
        self.logger.debug("special copy")

        simulateCopy() {
            guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                return
            }

            self.logger.debug("copied '\(copiedText)'")

            // Clear the modal text and reissue request
            Task {
                await self.modalManager.clearText(stickyMode: stickyMode)
                await self.modalManager.showModal(incognito: incognitoMode)

                self.appContextManager.getActiveAppInfo { (appName, bundleIdentifier, url) in
                    var userMessage = ""
                    if let url = url {
                        userMessage += "app: \(appName ?? "unknown") (\(url))\n"
                    } else {
                        userMessage += "app: \(appName ?? "unknown")\n"
                    }

                    if let activePrompt = self.promptManager.getActivePrompt() {
                        userMessage += "\(activePrompt):\n\(copiedText)"
                    } else {
                        userMessage += "copied:\n\(copiedText)"
                    }

                    let history = self.historyManager.fetchHistoryEntries(
                        limit: 10,
                        quickActionId: self.promptManager.activePromptID,
                        activeUrl: url,
                        activeAppName: appName,
                        activeAppBundleIdentifier: bundleIdentifier
                    )

                    Task {
                        await self.modalManager.setUserMessage(userMessage)
                        await self.clientManager.sendStreamRequest(
                            id: UUID(),
                            token: UserDefaults.standard.string(forKey: "token") ?? "",
                            username: NSUserName(),
                            userFullName: NSFullUserName(),
                            userObjective: self.promptManager.getActivePrompt(),
                            userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                            userLang: Locale.preferredLanguages.first ?? "",
                            copiedText: copiedText,
                            messages: self.modalManager.messages,
                            history: history,
                            url: url ?? "",
                            activeAppName: appName ?? "unknown",
                            activeAppBundleIdentifier: bundleIdentifier ?? "",
                            incognitoMode: incognitoMode,
                            streamHandler: self.modalManager.defaultHandler,
                            completion: { _ in }
                        )
                    }
                }
            }
        }
    }
}
