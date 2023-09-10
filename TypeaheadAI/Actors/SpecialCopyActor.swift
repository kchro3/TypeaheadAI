//
//  SpecialCopyActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/10/23.
//

import Foundation
import SwiftUI
import os.log

actor SpecialCopyActor {
    private let clipboardMonitor: ClipboardMonitor
    private let clientManager: ClientManager
    private let modalManager: ModalManager
    
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCopyActor"
    )

    init(mouseEventMonitor: MouseEventMonitor,
         clientManager: ClientManager,
         modalManager: ModalManager) {
        self.clipboardMonitor = ClipboardMonitor(mouseEventMonitor: mouseEventMonitor)
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
                    stream: true
                ) { result in
                    switch result {
                    case .success(let chunk):
                        DispatchQueue.main.async {
                            self.modalManager.appendText(chunk)
                        }
                        self.logger.info("Received chunk: \(chunk)")
                    case .failure(let error):
                        self.logger.error("An error occurred: \(error)")
                    }
                }
            }
        }
    }

    private func simulateCopy(completion: @escaping () -> Void) {
        self.logger.debug("simulated copy")
        // Post a Command-C keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)! // c key
        cmdCDown.flags = [.maskCommand]
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)! // c key
        cmdCUp.flags = [.maskCommand]

        cmdCDown.post(tap: .cghidEventTap)
        cmdCUp.post(tap: .cghidEventTap)

        // Delay for the clipboard to update, then call the completion handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
    }
}
