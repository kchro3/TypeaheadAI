//
//  SpecialSaveActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import Foundation
import SwiftUI
import os.log

actor SpecialSaveActor: CanSimulateCopy {
    private let modalManager: ModalManager
    private let clientManager: ClientManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialSaveActor"
    )

    init(modalManager: ModalManager, clientManager: ClientManager) {
        self.modalManager = modalManager
        self.clientManager = clientManager
    }

    func specialSave(incognitoMode: Bool) {
        simulateCopy() {
            guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                return
            }

            self.logger.debug("saved '\(copiedText)'")
            // Clear the modal text and reissue request
            self.modalManager.clearText()
            self.modalManager.showModal(incognito: incognitoMode)
            self.modalManager.appendText("Saving...\n\n")
            self.clientManager.predict(
                id: UUID(),
                copiedText: copiedText,
                incognitoMode: incognitoMode,
                userObjective: "tldr the copied text in 20 words or less",
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
                completion: { result in
                    switch result {
                    case .success(let output):
                        self.logger.info("text: \(output)")
                    case .failure(let error):
                        self.logger.error("An error occurred: \(error)")
                    }
                }
            )
        }
    }
}
