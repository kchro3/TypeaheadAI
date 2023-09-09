//
//  SpecialCutActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/8/23.
//

import Foundation
import Carbon.HIToolbox
import AppKit
import Cocoa
import os.log

class ClipboardMonitor {
    private var timer: Timer?
    private var pasteboardChangeCount: Int
    var onScreenshotDetected: (() -> Void)?

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClipboardMonitor"
    )

    init() {
        self.pasteboardChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        logger.debug("start monitoring")
        timer = Timer(timeInterval: 0.5, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .default)
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
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}

actor SpecialCutActor {
    private let clipboardMonitor = ClipboardMonitor()
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCutActor"
    )

    func specialCut() {
        do {
            try simulateScreengrab() {
                self.logger.info("done")
            }
        } catch {
            self.logger.error("Failed to execute special cut: \(error)")
        }
    }

    private func simulateScreengrab(completion: @escaping () -> Void) throws {
        clipboardMonitor.onScreenshotDetected = {
            completion()
        }
        clipboardMonitor.startMonitoring()

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw CustomError.eventSourceCreationFailed
        }

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x56, keyDown: true)!
        down.flags = [.maskCommand, .maskControl, .maskShift]
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x56, keyDown: false)!
        up.flags = [.maskCommand, .maskControl, .maskShift]

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)

        // If the user clicks without dragging (initial mouse down == mouse up),
        // then the screen capture is canceled.
        var initialMouseLocation: NSPoint?
        logger.debug("listen for mouse events")
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
            switch event.type {
            case .leftMouseDown:
                self.logger.debug("mouse down")
                initialMouseLocation = NSEvent.mouseLocation
                print(NSEvent.mouseLocation)
            case .leftMouseUp:
                self.logger.debug("mouse up")
                print(NSEvent.mouseLocation)
                if let initialLocation = initialMouseLocation, NSEvent.mouseLocation == initialLocation {
                    self.clipboardMonitor.stopMonitoring()
                    completion()
                }
            default:
                break
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 10.0) {
            NSEvent.removeMonitor(globalMonitor!)
            self.clipboardMonitor.stopMonitoring()
        }
    }

    enum CustomError: Error {
        case eventSourceCreationFailed
    }
}
