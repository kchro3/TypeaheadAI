//
//  SpecialCutActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/8/23.
//

import Foundation
import SwiftUI
import os.log

struct ImageCaptionPayload: Codable {
    let caption: String
}

actor SpecialCutActor: CanPerformOCR {
    private let clipboardMonitor: ClipboardMonitor
    private let promptManager: PromptManager
    private let clientManager: ClientManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    @AppStorage("numSmartCuts") var numSmartCuts: Int?
    @AppStorage("bio") var bio: String?

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCutActor"
    )

    private struct Constants {
        static let thresholdX: CGFloat = 0.01
        static let thresholdY: CGFloat = 0.02
    }

    init(mouseEventMonitor: MouseEventMonitor,
         promptManager: PromptManager,
         clientManager: ClientManager,
         modalManager: ModalManager,
         appContextManager: AppContextManager
    ) {
        self.clipboardMonitor = ClipboardMonitor(mouseEventMonitor: mouseEventMonitor)
        self.promptManager = promptManager
        self.clientManager = clientManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }

    func specialCut(stickyMode: Bool) {
        self.appContextManager.getActiveAppInfo { appContext in
            do {
                self.clipboardMonitor.stopMonitoring()
                try self.simulateScreengrab() {
                    guard let tiffData = NSPasteboard.general.data(forType: .tiff),
                          let image = NSImage(data: tiffData),
                          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        self.logger.error("Failed to retrieve image from clipboard")
                        return
                    }

                    if false {
                        self.performOCR(image: cgImage) { recognizedText, _ in
                            self.logger.info("OCRed text: \(recognizedText)")
                            Task {
                                await self.modalManager.clearText(stickyMode: stickyMode)
                                await self.modalManager.showModal()
                                await NSApp.activate(ignoringOtherApps: true)

                                if let captionPayload = await self.clientManager.captionImage(tiffData: tiffData) {
                                    await self.modalManager.appendUserImage(tiffData, caption: captionPayload.caption, ocrText: recognizedText)

                                    if let nCuts = self.numSmartCuts {
                                        self.numSmartCuts = nCuts + 1
                                    } else {
                                        self.numSmartCuts = 1
                                    }

                                    do {
                                        if let intents = try await self.clientManager.suggestIntents(
                                            id: UUID(),
                                            username: NSUserName(),
                                            userFullName: NSFullUserName(),
                                            userObjective: self.promptManager.getActivePrompt(),
                                            userBio: self.bio ?? "",
                                            userLang: Locale.preferredLanguages.first ?? "",
                                            copiedText: captionPayload.caption,
                                            messages: self.modalManager.messages,
                                            history: [],
                                            appContext: appContext,
                                            incognitoMode: !self.modalManager.online
                                        ), !intents.intents.isEmpty {
                                            await self.modalManager.setUserIntents(intents: intents.intents)
                                        } else {
                                            await self.modalManager.replyToUserMessage(refresh: false)
                                        }
                                    } catch {
                                        self.logger.error("\(error.localizedDescription)")
                                        await self.modalManager.setError(error.localizedDescription)
                                    }
                                }
                            }
                        }
                    } else {
                        self.performOCR(image: cgImage) { recognizedText, _ in
                            self.logger.info("OCRed text: \(recognizedText)")

                            Task {
                                await self.modalManager.clearText(stickyMode: stickyMode)
                                await self.modalManager.showModal()
                                await NSApp.activate(ignoringOtherApps: true)

                                if let activePrompt = self.clientManager.getActivePrompt() {
                                    await self.modalManager.setUserMessage("\(activePrompt)\n:\(recognizedText)")
                                } else {
                                    await self.modalManager.setUserMessage("OCR'ed text:\n\(recognizedText)")
                                }

                                if let nCuts = self.numSmartCuts {
                                    self.numSmartCuts = nCuts + 1
                                } else {
                                    self.numSmartCuts = 1
                                }

                                do {
                                    if let intents = try await self.clientManager.suggestIntents(
                                        id: UUID(),
                                        username: NSUserName(),
                                        userFullName: NSFullUserName(),
                                        userObjective: self.promptManager.getActivePrompt(),
                                        userBio: self.bio ?? "",
                                        userLang: Locale.preferredLanguages.first ?? "",
                                        copiedText: recognizedText,
                                        messages: self.modalManager.messages,
                                        history: [],
                                        appContext: appContext,
                                        incognitoMode: !self.modalManager.online
                                    ), !intents.intents.isEmpty {
                                        await self.modalManager.setUserIntents(intents: intents.intents)
                                    } else {
                                        await self.modalManager.replyToUserMessage(refresh: false)
                                    }
                                } catch {
                                    self.logger.error("\(error.localizedDescription)")
                                    await self.modalManager.setError(error.localizedDescription)
                                }
                            }
                        }
                    }
                }
            } catch {
                self.logger.error("Failed to execute special cut: \(error)")
            }
        }
    }

    private func simulateScreengrab(completion: @escaping () -> Void) throws {
        clipboardMonitor.onScreenshotDetected = {
            completion()
        }
        clipboardMonitor.startMonitoring()

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw CustomError.eventSourceCreationFailed
        }

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x56, keyDown: true)!
        down.flags = [.maskCommand, .maskControl, .maskShift]
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x56, keyDown: false)!
        up.flags = [.maskCommand, .maskControl, .maskShift]

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    enum CustomError: Error {
        case eventSourceCreationFailed
    }
}
