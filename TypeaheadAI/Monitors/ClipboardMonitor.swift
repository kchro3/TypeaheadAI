//
//  ClipboardMonitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/9/23.
//

import AppKit
import Foundation
import os.log

/// This polls the clipboard to see if anything new has been added to the clipboard.
class ClipboardMonitor {
    private var timer: Timer?
    private var pasteboardChangeCount: Int
    var onScreenshotDetected: (() -> Void)?
    private let mouseEventMonitor: MouseEventMonitor

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClipboardMonitor"
    )

    init(mouseEventMonitor: MouseEventMonitor) {
        self.mouseEventMonitor = mouseEventMonitor
        self.pasteboardChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        logger.debug("start monitoring")
        // TODO: Maybe this should be a separate variable? Could introduce race conditions
        self.mouseEventMonitor.mouseClicked = false
        timer = Timer(timeInterval: 0.5, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .default)  // Needed to kick off the timer
    }

    @objc private func timerFired() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != self.pasteboardChangeCount {
            self.pasteboardChangeCount = currentChangeCount

            if NSPasteboard.general.data(forType: .tiff) != nil {
                logger.debug("Screenshot detected on clipboard")
                onScreenshotDetected?()
                self.stopMonitoring()
            }
        }

        if mouseEventMonitor.mouseClicked {
            logger.debug("Click detected. Exiting...")
            self.stopMonitoring()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}
