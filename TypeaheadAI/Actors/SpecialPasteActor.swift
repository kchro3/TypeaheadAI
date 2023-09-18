//
//  SpecialPasteActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/18/23.
//

import AVFoundation
import Foundation
import UserNotifications
import SwiftUI
import os.log


actor SpecialPasteActor: CanSimulatePaste {
    private let historyManager: HistoryManager
    private let mouseEventMonitor: MouseEventMonitor
    private let clientManager: ClientManager
    private let memoManager: MemoManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialPasteActor"
    )

    init(
        historyManager: HistoryManager,
        mouseEventMonitor: MouseEventMonitor,
        clientManager: ClientManager,
        memoManager: MemoManager
    ) {
        self.historyManager = historyManager
        self.mouseEventMonitor = mouseEventMonitor
        self.clientManager = clientManager
        self.memoManager = memoManager
    }

    func specialPaste(incognitoMode: Bool, completion: @escaping () -> Void) {
        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            AudioServicesPlaySystemSound(1306) // Funk sound
            return
        }

        let newEntry = self.historyManager.addHistoryEntry(query: copiedText)
        self.mouseEventMonitor.mouseClicked = false // Unset flag

        Task {
            self.clientManager.predict(
                id: newEntry.id!,
                copiedText: copiedText,
                incognitoMode: incognitoMode,
                streamHandler: { _ in },
                completion: { result in
                    switch result {
                    case .success(let response):
                        self.logger.info("Response from server: \(response)")

                        // Save to clipboard
                        let pasteboard = NSPasteboard.general
                        pasteboard.prepareForNewContents()
                        pasteboard.setString(response, forType: .string)

                        // Update history
                        self.historyManager.updateHistoryEntry(
                            entry: newEntry,
                            withResponse: response,
                            andStatus: .success
                        )

                        if self.mouseEventMonitor.mouseClicked {
                            self.sendClipboardNotification(status: .success)
                        } else {
                            AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
                            self.simulatePaste(completion: {() in })
                        }
                    case .failure(let error):
                        self.logger.error("\(error.localizedDescription)")
                        self.historyManager.updateHistoryEntry(
                            entry: newEntry,
                            withResponse: nil,
                            andStatus: .failure
                        )

                        self.sendClipboardNotification(status: .failure)
                        AudioServicesPlaySystemSound(1306) // Funk sound
                    }

                    // Finish up
                    DispatchQueue.main.async {
                        completion()
                    }
                })
        }
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
