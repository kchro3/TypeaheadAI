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
    
    func specialCopy(incognitoMode: Bool) {
        self.logger.debug("special copy")

        let initialCopiedText = NSPasteboard.general.string(forType: .string) ?? ""

        simulateCopy() {
            guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                return
            }

            self.logger.debug("copied '\(copiedText)'")
            if copiedText == initialCopiedText && self.modalManager.hasText() {
                // If nothing changed, then toggle the modal.
                // NOTE: If the modal is empty but the clipboard is not,
                // whatever was in the clipboard initially is from a regular
                // copy, in which case we just do the regular flow.
                self.modalManager.toggleModal(incognito: incognitoMode)
            } else {
                // Clear the modal text and reissue request
                self.modalManager.clearText()
                self.modalManager.showModal(incognito: incognitoMode)
                self.clientManager.predict(
                    id: UUID(),
                    copiedText: copiedText,
                    incognitoMode: incognitoMode,
                    stream: true,
                    streamHandler: { result in
                        switch result {
                        case .success(let chunk):
                            DispatchQueue.main.async {
                                self.modalManager.appendText(chunk)
                            }
                            self.logger.info("Received chunk: \(chunk)")
                        case .failure(let error):
                            self.logger.error("An error occurred: \(error)")
                        }
                    },
                    completion: { _ in }
                )
            }
        }
    }
}
