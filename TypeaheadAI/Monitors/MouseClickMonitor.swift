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

                    let systemWideElement = AXUIElementCreateSystemWide()
                    var element: AXUIElement?

                    let point = CGPoint(x: mousePos.x, y: NSHeight(NSScreen.screens[0].frame) - mousePos.y)
                    let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &element)
                    if result == .success, let element = element, let uiElement = UIElement(from: element), let serialized = uiElement.serialize() {
                        print(serialized)
                    }

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
