//
//  ClipboardMonitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import AppKit
import Foundation
import os.log

/// This polls the clipboard to see if anything new has been added to the clipboard.
class ClipboardMonitor {
    private var timer: Timer?
    private var pasteboardChangeCount: Int
    var onCopy: (() async throws -> Void)?

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClipboardMonitor"
    )

    init() {
        self.pasteboardChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring(onCopy: @escaping () async throws -> Void) {
        self.onCopy = onCopy
        logger.debug("start monitoring")
        timer = Timer(timeInterval: 0.1, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .default)  // Needed to kick off the timer
    }

    @objc private func timerFired() {
        logger.debug("fire")
        Task {
            let currentChangeCount = NSPasteboard.general.changeCount
            if currentChangeCount != self.pasteboardChangeCount {
                self.pasteboardChangeCount = currentChangeCount
                try await onCopy?()
                self.stopMonitoring()
            }
        }
    }

    func stopMonitoring() {
        onCopy = nil
        timer?.invalidate()
        timer = nil
    }
}
