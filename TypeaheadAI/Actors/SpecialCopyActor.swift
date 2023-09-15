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
            self.modalManager.showModal(incognito: incognitoMode)

            Task {
                await self.modalManager.clearText(stickyMode: stickyMode)
                if let activePrompt = self.clientManager.getActivePrompt() {
                    await self.modalManager.setUserMessage("\(activePrompt):\n\(copiedText)")
                } else {
                    await self.modalManager.setUserMessage("copied:\n\(copiedText)")
                }

                self.clientManager.refine(
                    messages: self.modalManager.messages,
                    incognitoMode: incognitoMode,
                    streamHandler: { result in
                        switch result {
                        case .success(let chunk):
                            Task {
                                await self.modalManager.appendText(chunk)
                            }
                            self.logger.info("Received chunk: \(chunk)")
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.modalManager.setError(error.localizedDescription)
                            }
                            self.logger.error("An error occurred: \(error)")
                        }
                    }
                )
            }
        }
    }
}
