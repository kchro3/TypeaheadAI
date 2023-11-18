//
//  SpecialPasteActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import AVFoundation
import Foundation
import UserNotifications
import SwiftUI
import os.log

actor SpecialPasteActor: CanSimulatePaste, CanPerformOCR {
    private let appContextManager: AppContextManager
    private let clientManager: ClientManager
    private let historyManager: HistoryManager
    private let intentManager: IntentManager
    private let modalManager: ModalManager
    private let promptManager: QuickActionManager

    @AppStorage("numSmartPastes") var numSmartPastes: Int?

    private let optionShiftCommandPasteApps = [
        "Numbers"
    ]

    private let optionCommandPasteApps = [
        "Excel"
    ]

    private let shiftPasteUrls = [
        "https://docs.google.com/spreadsheets"
    ]

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialPasteActor"
    )

    init(
        appContextManager: AppContextManager,
        clientManager: ClientManager,
        historyManager: HistoryManager,
        intentManager: IntentManager,
        modalManager: ModalManager,
        promptManager: QuickActionManager
    ) {
        self.appContextManager = appContextManager
        self.clientManager = clientManager
        self.historyManager = historyManager
        self.intentManager = intentManager
        self.modalManager = modalManager
        self.promptManager = promptManager
    }

    func specialPaste() async throws {
        var appContext = try await self.appContextManager.getActiveAppInfo()
        if modalManager.isVisible {
            print("visible")
            guard let lastMessage = self.modalManager.messages.last, !lastMessage.isCurrentUser else {
                return
            }

            let pasteboard = NSPasteboard.general
            pasteboard.prepareForNewContents()

            // just a proof of concept
            var isTable = false
            if let results = lastMessage.attributed?.results {
                pasteboard.setString(lastMessage.text, forType: .string)
                for result in results {
                    if case .table = result.parsedType {
                        pasteboard.setString(NSAttributedString(result.attributedString).string, forType: .string)
                        isTable = true
                        break
                    } else if case .codeBlock(_) = result.parsedType {
                        pasteboard.setString(NSAttributedString(result.attributedString).string, forType: .string)
                        break
                    }
                }
            } else if case .image(let imageData) = lastMessage.messageType {
                if let data = Data(base64Encoded: imageData.image) {
                    pasteboard.setData(data, forType: .tiff)
                }
            } else {
                pasteboard.setString(lastMessage.text, forType: .string)
            }

            guard let firstMessage = self.modalManager.messages.first else {
                self.logger.error("Illegal state")
                return
            }

            await self.historyManager.addHistoryEntry(
                copiedText: firstMessage.text,
                pastedResponse: lastMessage.text,
                quickActionId: self.promptManager.activePromptID,
                activeUrl: appContext?.url?.host,
                activeAppName: appContext?.appName,
                activeAppBundleIdentifier: appContext?.bundleIdentifier,
                numMessages: self.modalManager.messages.count
            )

            if isTable {
                if let url = appContext?.url,
                   let _ = self.shiftPasteUrls.first(where: { w in url.absoluteString.starts(with: w) }) {
                    try await self.simulatePaste(flags: [.maskShift, .maskCommand])
                } else if let appName = appContext?.appName,
                          self.optionShiftCommandPasteApps.contains(appName) {
                    try await self.simulatePaste(flags: [.maskAlternate, .maskShift, .maskCommand])
                } else if let appName = appContext?.appName,
                          self.optionCommandPasteApps.contains(appName) {
                    try await self.simulatePaste(flags: [.maskAlternate, .maskCommand])
                } else {
                    try await self.simulatePaste()
                }
            } else {
                try await self.simulatePaste()
            }

            if let nPastes = self.numSmartPastes {
                self.numSmartPastes = nPastes + 1
            } else {
                self.numSmartPastes = 1
            }

            await self.modalManager.closeModal()
        } else {
            print("hidden")
            await self.modalManager.forceRefresh()
            await self.modalManager.showModal()
            await NSApp.activate(ignoringOtherApps: true)

            // Set the OCR'ed text
            if let screenshot = appContext?.screenshotPath.flatMap({ NSImage(contentsOfFile: $0)?.toCGImage() }) {
                print("performing OCR")
                let (ocrText, _) = try await performOCR(image: screenshot)
                appContext?.ocrText = ocrText
            }

            // Try to predict the user intent
            let contextualIntents = self.intentManager.fetchContextualIntents(limit: 3, appContext: appContext)
            await self.modalManager.setUserIntents(intents: contextualIntents)

            // Kick off async
            Task {
                if let intents = try await self.clientManager.suggestIntents(
                    id: UUID(),
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: self.promptManager.getActivePrompt(),
                    userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                    userLang: Locale.preferredLanguages.first ?? "",
                    copiedText: appContext?.copiedText ?? "",
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
}

// Define the notification name extension somewhere in your codebase
extension Notification.Name {
    static let smartPastePerformed = Notification.Name("smartPastePerformed")
}
