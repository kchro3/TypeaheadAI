//
//  SpecialPasteActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/6/23.
//

import AppKit
import Foundation
import os.log

actor SpecialPasteActor {
    private var chunkBuffer: [String] = []

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialPasteActor"
    )

    func specialPaste(
        clientManager: ClientManager,
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String,
        copiedText: String,
        url: String,
        activeAppName: String,
        activeAppBundleIdentifier: String,
        incognitoMode: Bool
    ) async {
        Task.detached { [self] in
            await clientManager.sendStreamRequest(
                id: id,
                username: username,
                userFullName: userFullName,
                userObjective: userObjective,
                copiedText: copiedText,
                url: url,
                activeAppName: activeAppName,
                activeAppBundleIdentifier: activeAppBundleIdentifier,
                incognitoMode: incognitoMode
            ) { [self] (chunk, error) in
                Task {
                    await self.receiveChunk(chunk, error: error)
                }
            }
        }
    }

    func receiveChunk(_ chunk: String?, error: Error?) async {
        if let error = error {
            self.logger.error("An error occurred: \(error.localizedDescription)")
            return
        }

        if let chunk = chunk {
            chunkBuffer.append(chunk)
        }

        await flushBufferToPasteboard()
    }

    func flushBufferToPasteboard() async {
        guard !chunkBuffer.isEmpty else {
            return
        }
        let chunkData = self.chunkBuffer.joined()
        self.logger.debug("chunkData: \(chunkData)")
        self.chunkBuffer.removeAll()

        DispatchQueue.main.async {
            Task {
                NSPasteboard.general.setString(chunkData, forType: .string)
                await self.simulatePaste()
            }
        }
    }

    private func simulatePaste() {
        self.logger.debug("simulated paste")
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        cmdVDown.flags = [.maskCommand]
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key
        cmdVUp.flags = [.maskCommand]

        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)
    }
}
