//
//  SpecialPasteActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/14/23.
//

import AVFoundation
import UserNotifications
import Foundation
import SwiftUI
import os.log

actor SpecialPasteActor: CanSimulatePaste {
    private let modalManager: ModalManager
    private let memoManager: MemoManager
    private let historyManager: HistoryManager
    private let mouseEventMonitor: MouseEventMonitor

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialPasteActor"
    )

    init(
        modalManager: ModalManager,
        memoManager: MemoManager,
        historyManager: HistoryManager,
        mouseEventMonitor: MouseEventMonitor
    ) {
        self.modalManager = modalManager
        self.memoManager = memoManager
        self.historyManager = historyManager
        self.mouseEventMonitor = mouseEventMonitor
    }

    func specialPaste(
        incognitoMode: Bool
    ) {
        self.logger.debug("special paste")

        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            self.logger.debug("Nothing in the clipboard")
            return
        }

        let newEntry = self.historyManager.addHistoryEntry(query: copiedText)

        DispatchQueue.main.async {
            self.modalManager.startBlinking()
        }

        self.modalManager.clientManager?.predict(
            id: newEntry.id!,
            copiedText: copiedText,
            incognitoMode: incognitoMode,
            streamHandler: { _ in },
            completion: { result in
                DispatchQueue.main.async {
                    self.modalManager.stopBlinking()
                }
                switch result {
                case .success(let response):
                    self.logger.debug("Response from server: \(response)")
                    NSPasteboard.general.setString(response, forType: .string)
                    // Simulate a paste of the lowercase string
                    if self.mouseEventMonitor.mouseClicked || newEntry.id != self.historyManager.mostRecentPending() {
                        self.sendClipboardNotification(status: .success)
                    } else {
                        self.simulatePaste() {
                            AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
                        }
                    }
                    self.historyManager.updateHistoryEntry(
                        entry: newEntry,
                        withResponse: response,
                        andStatus: .success
                    )
                case .failure(let error):
                    self.logger.debug("Error: \(error.localizedDescription)")
                    self.historyManager.updateHistoryEntry(
                        entry: newEntry,
                        withResponse: nil,
                        andStatus: .failure
                    )
                    self.sendClipboardNotification(status: .failure)
                    AudioServicesPlaySystemSound(1306) // Funk sound
                }
            }
        )
    }

    private func sendClipboardNotification(status: RequestStatus) {
        let content = UNMutableNotificationContent()

        if status == RequestStatus.success {
            content.title = "Clipboard Ready"
            content.body = "Paste with cmd-v."
        } else {
            content.title = "Failed to paste"
            content.body = "Something went wrong... Please try again."
        }
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}
