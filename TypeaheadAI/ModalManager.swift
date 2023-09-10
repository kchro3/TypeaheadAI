//
//  ModalManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/2/23.
//

import AppKit
import SwiftUI
import Foundation

class ModalManager: ObservableObject {
    @Published var modalText: String = ""

    var toastWindow: NSWindow?

    func hasText() -> Bool {
        return !modalText.isEmpty
    }

    func clearText() {
        modalText = ""
    }

    func setText(_ text: String) {
        modalText = text
    }

    func appendText(_ text: String) {
        modalText += text
    }

    func showSpecialCopyModal() {
        toastWindow?.close()

        // Create the visual effect view with frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow

        // Create the content view
        let contentView = ModalView(
            showModal: .constant(true),
            copyModalManager: self
        )

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Create a base view to hold both the visualEffect and hostingView
        let baseView = NSView()

        // Create the window
        toastWindow = CustomModalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [
                .closable,
                .fullSizeContentView,
                .resizable,
                .titled
            ],
            backing: .buffered,
            defer: false
        )

        // Set the base effect view as the window's content view
        toastWindow?.contentView = baseView

        // Now that baseView has a frame, set the frames for visualEffect and hostingView
        visualEffect.frame = baseView.bounds
        visualEffect.autoresizingMask = [.width, .height]

        hostingView.frame = baseView.bounds

        // Add visualEffect and hostingView to baseView
        baseView.addSubview(visualEffect)
        baseView.addSubview(hostingView)

        // Add constraints to make the hosting view fill the base view
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: baseView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor)
        ])

        // Set the x, y coordinates and the size to the user's last preference or the center by default
        let x = UserDefaults.standard.value(forKey: "toastWindowX") as? CGFloat
        let y = UserDefaults.standard.value(forKey: "toastWindowY") as? CGFloat
        let width = UserDefaults.standard.value(forKey: "toastWindowSizeWidth") as? CGFloat
        let height = UserDefaults.standard.value(forKey: "toastWindowSizeHeight") as? CGFloat

        if let x = x, let y = y, let width = width, let height = height {
            toastWindow?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        } else {
            toastWindow?.setFrame(NSRect(x: 0, y: 0, width: 300, height: 200), display: true)
            toastWindow?.center()
        }

        toastWindow?.titlebarAppearsTransparent = true
        toastWindow?.isMovableByWindowBackground = true
        toastWindow?.isReleasedWhenClosed = false
        toastWindow?.level = .popUpMenu
        toastWindow?.makeKeyAndOrderFront(nil)

        // Register for window moved notifications to save the new position
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification, object: toastWindow)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize(_:)),
            name: NSWindow.didResizeNotification, object: toastWindow)
    }

    @objc func windowDidMove(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let origin = movedWindow.frame.origin

            UserDefaults.standard.set(origin.x, forKey: "toastWindowX")
            UserDefaults.standard.set(origin.y, forKey: "toastWindowY")
        }
    }

    @objc func windowDidResize(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let size = movedWindow.frame.size

            UserDefaults.standard.set(size.width, forKey: "toastWindowSizeWidth")
            UserDefaults.standard.set(size.height, forKey: "toastWindowSizeHeight")
            print("Saved width: \(size.width), height: \(size.height)")
        }
    }
}
