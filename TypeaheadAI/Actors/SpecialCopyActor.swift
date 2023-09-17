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
    private let clientManager: ClientManager
    private let modalManager: ModalManager
    @AppStorage("numCopies") var numCopies: Int?
    
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCopyActor"
    )

    init(clientManager: ClientManager,
         modalManager: ModalManager) {
        self.clientManager = clientManager
        self.modalManager = modalManager
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

                var truncated: String = copiedText
                if (copiedText.count > 280) {
                    truncated = "\(truncated.prefix(280))..."
                }

                self.clientManager.appContextManager!.getActiveAppInfo { (appName, bundleIdentifier, url) in
                    var userMessage = ""
                    if let url = url {
                        userMessage += "app: \(appName ?? "unknown") (\(url))\n"
                    } else {
                        userMessage += "app: \(appName ?? "unknown")\n"
                    }

                    if let activePrompt = self.clientManager.getActivePrompt() {
                        userMessage += "\(activePrompt):\n\(truncated)"
                    } else {
                        userMessage += "copied:\n\(truncated)"
                    }

                    Task {
                        await self.modalManager.setUserMessage(userMessage)
                        self.clientManager.predict(
                            id: UUID(),
                            copiedText: copiedText,
                            incognitoMode: incognitoMode,
                            stream: true,
                            streamHandler: self.modalManager.defaultHandler,
                            completion: { _ in
                                if let nCopies = self.numCopies {
                                    self.numCopies = nCopies + 1
                                } else {
                                    self.numCopies = 0
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}
