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

    func specialPaste() {
        guard let lastMessage = self.modalManager.messages.last, !lastMessage.isCurrentUser else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.prepareForNewContents()

        // just a proof of concept
        if let results = lastMessage.attributed?.results {
            pasteboard.setString(lastMessage.text, forType: .string)
            for result in results {
                if case .codeBlock(_) = result.parsedType {
                    if shouldPasteHTML(result: result) {
                        // Overwrite with the html string if conditions are met
                        pasteboard.setString(NSAttributedString(result.attributedString).string, forType: .html)
                    } else {
                        // Overwrite with the code block if it exists
                        pasteboard.setString(NSAttributedString(result.attributedString).string, forType: .string)
                    }

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

    private func shouldPasteHTML(result: ParserResult) -> Bool {
        guard case .codeBlock(let langOpt) = result.parsedType,
              let lang = langOpt, lang.lowercased() == "html" else {
            // If the result isn't an HTML codeblock, then false
            return false
        }

        guard let firstMessage = self.modalManager.messages.first,
              firstMessage.isCurrentUser else {
            // If the first messages isn't the user, then false (could be relaxed)
            return false
        }

        guard case .html(_) = firstMessage.messageType else {
            // If the first message isn't HTML, then false (could be relaxed)
            return false
        }

        return true
    }
}
