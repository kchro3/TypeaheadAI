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
    private let memoManager: MemoManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialSaveActor"
    )

    init(
        modalManager: ModalManager,
        clientManager: ClientManager,
        memoManager: MemoManager
    ) {
        self.modalManager = modalManager
        self.clientManager = clientManager
        self.memoManager = memoManager
    }

    func specialSave(incognitoMode: Bool) {
        simulateCopy() {
            guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                return
            }

            self.logger.debug("saved '\(copiedText)'")
            // Force sticky-mode so that it saves the message to the session.
            self.modalManager.clearText(stickyMode: true)
            self.modalManager.showModal(incognito: incognitoMode)

            Task {
                await self.modalManager.appendText("Saving...\n")
            }

            self.clientManager.predict(
                id: UUID(),
                copiedText: copiedText,
                incognitoMode: incognitoMode,
                userObjective: "tldr the copied text in 20 words or less",
                stream: true,
                streamHandler: self.modalManager.defaultHandler,
                completion: { result in
                    switch result {
                    case .success(let output):
                        _ = self.memoManager.createEntry(summary: output, content: copiedText)
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
