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
    private let logger: Logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "MouseEventMonitor"
    )

    var mouseClicked: Bool = false
    var onLeftMouseDown: (() -> Void)?

    func startMonitoring() {
        logger.debug("Starting to monitor mouse clicks.")
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: { [weak self] _ in
            self?.mouseClicked = true
            self?.onLeftMouseDown?()
        })
    }

    func stopMonitoring() async {
        if let mouseEventMonitor = mouseEventMonitor {
            logger.debug("Stopping mouse click monitoring.")
            NSEvent.removeMonitor(mouseEventMonitor)
            self.mouseEventMonitor = nil
        }
    }
}
