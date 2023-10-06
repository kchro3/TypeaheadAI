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

                    if let nCopies = self.numSmartCopies {
                        self.numSmartCopies = nCopies + 1
                    } else {
                        self.numSmartCopies = 1
                    }

                    if let quickActionId = self.promptManager.activePromptID {

                        // NOTE: If the user has specified a quick action, execute the quick action. Use the few-shot mode to reference previously successful copy-pastes.
                        let history = self.historyManager.fetchHistoryEntries(
                            limit: 10,
                            quickActionId: quickActionId,
                            activeUrl: appContext?.url?.host,
                            activeAppName: appContext?.appName,
                            activeAppBundleIdentifier: appContext?.bundleIdentifier
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
                                url: appContext?.url?.host ?? "",
                                activeAppName: appContext?.appName ?? "unknown",
                                activeAppBundleIdentifier: appContext?.bundleIdentifier ?? "",
                                incognitoMode: !self.modalManager.online,
                                streamHandler: self.modalManager.defaultHandler,
                                completion: { _ in
                                    DispatchQueue.main.async {
                                        self.modalManager.isPending = false
                                    }
                                }
                            )
                        }
                    } else {
                        let previousPrompts = self.clientManager.intentManager?.fetchIntents(
                            limit: 10,
                            url: appContext?.url?.host,
                            appName: appContext?.appName,
                            bundleIdentifier: appContext?.bundleIdentifier
                        )

                        Task {
                            await self.modalManager.setUserMessage(copiedText, messageType: messageType)
                            do {
                                if let intents = try await self.clientManager.suggestIntents(
                                    id: UUID(),
                                    token: UserDefaults.standard.string(forKey: "token") ?? "",
                                    username: NSUserName(),
                                    userFullName: NSFullUserName(),
                                    userObjective: self.promptManager.getActivePrompt(),
                                    userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                                    userLang: Locale.preferredLanguages.first ?? "",
                                    copiedText: copiedText,
                                    messages: self.modalManager.messages,
                                    history: previousPrompts,
                                    url: appContext?.url?.host ?? "",
                                    activeAppName: appContext?.appName ?? "unknown",
                                    activeAppBundleIdentifier: appContext?.bundleIdentifier ?? "",
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
            }
        }
    }
}
