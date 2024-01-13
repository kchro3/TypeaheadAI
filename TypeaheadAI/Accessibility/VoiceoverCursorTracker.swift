//
//  VoiceoverCursorTracker.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/12/24.
//

import AppKit
import Foundation

class VoiceoverCursorTracker {
    private var observer: AXObserver?

    init() {
        setupObserver()
    }

    private func setupObserver() {
        let application = NSRunningApplication.current
        var observer: AXObserver?
        let result = AXObserverCreate(application.processIdentifier, voCursorCallback, &observer)

        guard result == .success, let axObserver = observer else {
            print("Failed to create AXObserver")
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(axObserver), .defaultMode)
        self.observer = axObserver

        // Add notification for VO cursor change
        if let observer = observer {
            AXObserverAddNotification(observer, AXUIElementCreateSystemWide(), kAXFocusedUIElementChangedNotification as CFString, nil)
            print("Added notification")
        } else {
            print("no observer")
        }
    }
}

func voCursorCallback(observer: AXObserver, element: AXUIElement, notificationName: CFString, userInfo: UnsafeMutableRawPointer?) {
    print("VoiceOver cursor moved to a new element")
    printElementInfo(element: element)
}

func printElementInfo(element: AXUIElement) {
    var value: CFTypeRef?
    var title: CFTypeRef?
    var role: CFTypeRef?

    AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
    AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &title)
    AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

    print("Element Value: \(value as? String ?? "N/A")")
    print("Element Title: \(title as? String ?? "N/A")")
    print("Element Role: \(role as? String ?? "N/A")")
}
