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

        simulateCopy() {
            var messageType: MessageType = .string
            guard var copiedText = NSPasteboard.general.string(forType: .string) else {
                return
            }

            // TODO: Only support HTML tables for now
            if let html = NSPasteboard.general.data(forType: .html),
               let htmlString = String(data: html, encoding: .utf8),
               htmlString.contains("</table>") {
                messageType = .html(data: htmlString)
            }

            self.logger.debug("copied '\(copiedText)'")

            // Clear the modal text and reissue request
            Task {
                await self.modalManager.clearText(stickyMode: stickyMode)
                await self.modalManager.showModal()

                self.appContextManager.getActiveAppInfo { (appName, bundleIdentifier, url) in
                    if let nCopies = self.numSmartCopies {
                        self.numSmartCopies = nCopies + 1
                    } else {
                        self.numSmartCopies = 1
                    }

                    let history = self.historyManager.fetchHistoryEntries(
                        limit: 10,
                        quickActionId: self.promptManager.activePromptID,
                        activeUrl: url,
                        activeAppName: appName,
                        activeAppBundleIdentifier: bundleIdentifier
                    )

                    Task {
                        await self.modalManager.setUserMessage(copiedText, messageType: messageType)
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
                            incognitoMode: !self.modalManager.online,
                            streamHandler: self.modalManager.defaultHandler,
                            completion: { _ in }
                        )
                    }
                }
            }
        }
    }
}
