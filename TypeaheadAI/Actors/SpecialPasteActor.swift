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

    func specialPaste() async throws {
        let appContext = try await self.appContextManager.getActiveAppInfo()
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

        _ = self.historyManager.addHistoryEntry(
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

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .smartPastePerformed, object: nil)
        }
        if let nPastes = self.numSmartPastes {
            self.numSmartPastes = nPastes + 1
        } else {
            self.numSmartPastes = 1
        }

        await self.modalManager.closeModal()
    }
}

// Define the notification name extension somewhere in your codebase
extension Notification.Name {
    static let smartPastePerformed = Notification.Name("smartPastePerformed")
}
