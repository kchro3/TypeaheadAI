//
//  SpecialPasteActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import AVFoundation
import Foundation
import UserNotifications
import MarkdownUI
import SwiftUI
import os.log

actor SpecialPasteActor: CanSimulatePaste {
    private let historyManager: HistoryManager
    private let promptManager: QuickActionManager
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

    // NOTE: This is a whitelist of URLs where the expected output is HTML
    private let htmlUrls = [
        "https://mail.google.com"
    ]

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialPasteActor"
    )

    init(
        historyManager: HistoryManager,
        promptManager: QuickActionManager,
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

        let markdownContent = MarkdownContent(lastMessage.text)

        if let specialBlock = self.hasSpecialBlock(markdownContent) {
            switch specialBlock {
            case .codeBlock(_, let content):
                // If there is at least one code block, then store the first code block in the clipboard
                pasteboard.setString(content, forType: .string)
            case .table(_, let rows):
                // If there is at least one table, then store the first table in the clipboard as a TSV
                isTable = true
                let tsv = rows.map { row in
                    row.cells.map { cell in
                        self.getCellContent(content: cell.content)
                    }.joined(separator: "\t")
                }.joined(separator: "\n")

                pasteboard.setString(tsv, forType: .string)
            default:
                pasteboard.setString(lastMessage.text, forType: .string)
            }
        } else if case .image(let imageData) = lastMessage.messageType,
                  let data = Data(base64Encoded: imageData.image) {
            pasteboard.setData(data, forType: .tiff)
        } else if let url = appContext?.url,
                  let _ = self.htmlUrls.first(where: { w in url.absoluteString.starts(with: w) }) {
            pasteboard.setData(Data(markdownContent.renderHTML().utf8), forType: .html)
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
    }

    private func hasSpecialBlock(_ markdown: MarkdownContent) -> BlockNode? {
        return markdown.blocks.first(where: { node in
            switch node {
            case .codeBlock: return true
            case .table: return true
            default: return false
            }
        })
    }

    private func hasTable(_ markdown: MarkdownContent) -> BlockNode? {
        return markdown.blocks.first(where: { node in
            switch node {
            case .table: return true
            default: return false
            }
        })
    }

    private func getCellContent(content: [InlineNode]) -> String {
        if content.count == 1 {
            switch content[0] {
            case .text(let text): return text
            case .emphasis(let children):
                return getCellContent(content: children)
            case .strong(let children):
                return getCellContent(content: children)
            case .strikethrough(let children):
                return getCellContent(content: children)
            case .link(let destination, _): return destination
            default: return "<not supported>"
            }
        }

        return content.map { c in
            getCellContent(content: [c])
        }.joined(separator: "")
    }
}

// Define the notification name extension somewhere in your codebase
extension Notification.Name {
    static let smartPastePerformed = Notification.Name("smartPastePerformed")
}
