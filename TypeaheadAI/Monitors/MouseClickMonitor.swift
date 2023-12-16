//
//  MouseClickMonitor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import Cocoa
import os.log

class MouseEventMonitor {
    private var mouseEventMonitor: Any?
    private var initialClickPos: NSPoint?

    private let logger: Logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "MouseEventMonitor"
    )

    var mouseClicked: Bool = false
    var mouseDragged: Bool = false

    var onLeftMouseDown: (() -> Void)?

    func startMonitoring() {
        logger.debug("Starting to monitor mouse clicks.")
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .leftMouseUp],
            handler: { [weak self] event in
                switch event.type {
                case .leftMouseDown:
                    let mousePos = NSEvent.mouseLocation
                    self?.initialClickPos = mousePos
                    self?.mouseClicked = true
                    self?.onLeftMouseDown?()
                case .leftMouseUp:
                    if let initialClickPos = self?.initialClickPos {
                        if initialClickPos != NSEvent.mouseLocation {
                            self?.mouseDragged = true
                        }
                    }
                default:
                    break
                }
            })
    }

    func stopMonitoring() {
        if let mouseEventMonitor = mouseEventMonitor {
            logger.debug("Stopping mouse click monitoring.")
            NSEvent.removeMonitor(mouseEventMonitor)
            self.mouseEventMonitor = nil
        }
    }
}
