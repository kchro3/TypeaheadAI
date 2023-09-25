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


actor SpecialPasteActor: CanSimulatePaste {
    private let historyManager: HistoryManager
    private let promptManager: PromptManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    @AppStorage("numSmartPastes") var numSmartPastes: Int?

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialPasteActor"
    )

    init(
        historyManager: HistoryManager,
        promptManager: PromptManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.historyManager = historyManager
        self.promptManager = promptManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }

    func specialPaste(incognitoMode: Bool) {
        guard let lastMessage = self.modalManager.messages.last, !lastMessage.isCurrentUser else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents()

        if let results = lastMessage.attributed?.results {
            // If there's a code-block, then paste the code-block text.
            pasteboard.setString(lastMessage.text, forType: .string)
            for result in results {
                if result.isCodeBlock {
                    // Overwrite with the code block if it exists
                    pasteboard.setString(NSAttributedString(result.attributedString).string, forType: .string)
                    break
                }
            }
        } else {
            pasteboard.setString(lastMessage.text, forType: .string)
        }

        Task {
            guard let firstMessage = self.modalManager.messages.first else {
                self.logger.error("Illegal state")
                return
            }

            self.appContextManager.getActiveAppInfo(completion: { (appName, bundleIdentifier, url) in
                _ = self.historyManager.addHistoryEntry(
                    copiedText: firstMessage.text,
                    pastedResponse: lastMessage.text,
                    quickActionId: self.promptManager.activePromptID,
                    activeUrl: url,
                    activeAppName: appName,
                    activeAppBundleIdentifier: bundleIdentifier,
                    numMessages: self.modalManager.messages.count
                )
            })
        }

        if let nPastes = self.numSmartPastes {
            self.numSmartPastes = nPastes + 1
        } else {
            self.numSmartPastes = 1
        }

        self.simulatePaste(completion: { () in })
    }
}
