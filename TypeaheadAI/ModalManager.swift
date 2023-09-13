//
//  ModalManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/2/23.
//

import AppKit
import SwiftUI
import Foundation
import os.log

// TODO: Add to persistence
struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    let isCurrentUser: Bool
}

class ModalManager: ObservableObject {
    @Published var messages: [Message] = []

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ModalManager"
    )

    // TODO: Inject?
    var clientManager: ClientManager? = nil

    var toastWindow: NSWindow?

    func hasText() -> Bool {
        if let lastMessage = messages.last, !lastMessage.isCurrentUser {
            return !lastMessage.text.isEmpty
        } else {
            return false
        }
    }

    func clearText() {
        messages = []
    }

    func setText(_ text: String) {
        if let idx = messages.indices.last, !messages[idx].isCurrentUser {
            messages[idx].text = text
        } else {
            messages.append(Message(id: UUID(), text: text, isCurrentUser: false))
        }
    }

    /// Append text to the AI response. Creates a new message if there is nothing to append to.
    func appendText(_ text: String) {
        if let idx = messages.indices.last, !messages[idx].isCurrentUser {
            messages[idx].text += text
        } else {
            messages.append(Message(id: UUID(), text: text, isCurrentUser: false))
        }
    }

    /// Add a user message without flushing the modal text. Use this when there is an active prompt.
    func setUserMessage(_ text: String) {
        messages.append(Message(id: UUID(), text: text, isCurrentUser: true))
    }

    /// When a user responds, flush the current text to the messages array and add the system and user prompts
    func addUserMessage(_ text: String, incognito: Bool) {
        self.clientManager?.cancelStreamingTask()

        messages.append(Message(id: UUID(), text: text, isCurrentUser: true))
        messages.append(Message(id: UUID(), text: "", isCurrentUser: false))

        self.clientManager?.refine(messages: self.messages, incognitoMode: incognito) { result in
            switch result {
            case .success(let chunk):
                DispatchQueue.main.async {
                    self.appendText(chunk)
                }
                self.logger.info("Received chunk: \(chunk)")
            case .failure(let error):
                self.logger.error("An error occurred: \(error)")
            }
        }
    }

    func toggleModal(incognito: Bool) {
        if toastWindow?.isVisible ?? false {
            toastWindow?.close()
        } else {
            showModal(incognito: incognito)
        }
    }

    func showModal(incognito: Bool) {
        toastWindow?.close()

        // Create the visual effect view with frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow

        // Create the content view
        let contentView = ModalView(
            showModal: .constant(true),
            incognito: incognito,
            modalManager: self
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
        toastWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

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
