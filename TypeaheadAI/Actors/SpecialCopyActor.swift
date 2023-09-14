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
            self.modalManager.clearText(stickyMode: stickyMode)
            self.modalManager.showModal(incognito: incognitoMode)
            var truncated: String = copiedText
            if (copiedText.count > 280) {
                truncated = "\(truncated.prefix(280))..."
            }

            if let activePrompt = self.clientManager.getActivePrompt() {
                self.modalManager.setUserMessage("\(activePrompt)\n:\(truncated)")
            } else {
                self.modalManager.setUserMessage("copied:\n\(truncated)")
            }

            self.clientManager.predict(
                id: UUID(),
                copiedText: copiedText,
                incognitoMode: incognitoMode,
                stream: true,
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
                },
                completion: { _ in }
            )
        }
    }
}
