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

actor SpecialOpenActor: CanPerformOCR, CanGetUIElements {
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

//        hack()

        if forceRefresh {
            self.logger.debug("special new")
            try await self.modalManager.forceRefresh()
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
                // Set the OCR'ed text
                if let screenshot = appInfo.appContext?.screenshotPath.flatMap({
                    NSImage(contentsOfFile: $0)?.toCGImage()
                }) {
                    let (ocrText, _) = try await performOCR(image: screenshot)
                    appInfo.appContext?.ocrText = ocrText
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
                    appContext: appInfo.appContext,
                    incognitoMode: !self.modalManager.online
                ), !intents.intents.isEmpty {
                    await self.modalManager.appendUserIntents(intents: intents.intents)
                }
            }
        }
    }

    private func hack() {
        let jsonString = """
            {"tool_uses":[{"recipient_name":"functions.open_url","parameters":{"url":"https://mail.google.com/mail/u/0/#inbox?compose=new"}},{"recipient_name":"functions.perform_ui_action","parameters":{"actions":[{"id":"AXButton#0160FB27","action":"AXPress"}]}}]}
        """

        do {
            if let jsonData = jsonString.data(using: .utf8),
               let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: [[String: Any]]],
               let toolUses = json["tool_uses"] {
                for tool in toolUses {
                    print(tool)
                }
            }
        } catch {
            print("Error decoding arbitrary JSON: \(error)")
        }
    }
}
