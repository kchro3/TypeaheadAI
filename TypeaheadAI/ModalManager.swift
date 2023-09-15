//
//  ModalManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/2/23.
//

import AppKit
import SwiftUI
import Foundation
import Markdown
import os.log

struct AttributedOutput: Codable, Equatable {
    let string: String
    let results: [ParserResult]
}

struct AppContext: Codable, Equatable {
    var activeAppName: String?
    var activeAppBundleIdentifier: String?
    var url: String?
}

// TODO: Add to persistence
struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    var attributed: AttributedOutput? = nil
    let isCurrentUser: Bool
    var responseError: String?
    var appContext: AppContext?
}

class ModalManager: ObservableObject {
    @Published var messages: [Message]
    @Published var triggerFocus: Bool

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ModalManager"
    )
    // When streaming a result, we want to batch process tokens.
    // Since we stream tokens one at a time, we need a global variable to
    // track the token counts per batch.
    private var currentTextCount = 0
    private let parserThresholdTextCount = 5
    private let maxMessages = 20
    private var currentOutput: AttributedOutput?
    private let parsingTask = ResponseParsingTask()

    init() {
        self.messages = []
        self.triggerFocus = false
    }

    // TODO: Inject?
    var clientManager: ClientManager? = nil

    var toastWindow: NSWindow?

    func hasText() -> Bool {
        if let lastMessage = messages.last,
                !lastMessage.isCurrentUser {
            return !lastMessage.text.isEmpty
        } else {
            return false
        }
    }

    @MainActor
    func focus() {
        self.triggerFocus = true
    }

    @MainActor
    func clearText(stickyMode: Bool) {
        if stickyMode {
            // TODO: Should we do something smarter here?
            if let lastMessage = messages.last, !lastMessage.isCurrentUser {
                messages.append(Message(id: UUID(), text: "", isCurrentUser: false))
                messages = messages.suffix(maxMessages)
            }
        } else {
            messages = []
        }
        currentTextCount = 0
        currentOutput = nil
    }

    @MainActor
    func forceRefresh() {
        messages = []
        currentTextCount = 0
        currentOutput = nil
        self.clientManager?.flushCache()
    }

    func setText(_ text: String) {
        if let idx = messages.indices.last,
                !messages[idx].isCurrentUser {
            messages[idx].text += text
        } else {
            messages.append(Message(id: UUID(), text: text, isCurrentUser: false))
        }
    }

    /// Set an error message.
    @MainActor
    func setError(_ responseError: String) {
        if let idx = messages.indices.last, !messages[idx].isCurrentUser {
            messages[idx].responseError = responseError
        } else {
            messages.append(Message(
                id: UUID(),
                text: "",
                isCurrentUser: false,
                responseError: responseError)
            )
        }
    }

    /// Append text to the AI response. Creates a new message if there is nothing to append to.
    @MainActor
    func appendText(_ text: String) async {
        guard let idx = messages.indices.last, !messages[idx].isCurrentUser else {
            // If the AI response doesn't exist yet, create one.
            messages.append(Message(id: UUID(), text: text, isCurrentUser: false))
            currentTextCount = 0
            currentOutput = nil
            return
        }

        let isDarkMode = (NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua)

        messages[idx].text += text
        let streamText = messages[idx].text

        do {
            currentTextCount += text.count

            if currentTextCount >= parserThresholdTextCount {
                currentOutput = await parsingTask.parse(text: streamText, isDarkMode: isDarkMode)
                try Task.checkCancellation()
                currentTextCount = 0
            }

            // Check if the parser detected anything
            if let currentOutput = currentOutput, !currentOutput.results.isEmpty {
                let suffixText = streamText.trimmingPrefix(currentOutput.string)
                var results = currentOutput.results
                let lastResult = results[results.count - 1]
                var lastAttrString = lastResult.attributedString
                if lastResult.isCodeBlock, let font = NSFont.preferredFont(forTextStyle: .body).apply(newTraits: .monoSpace) {
                    lastAttrString.append(
                        AttributedString(
                            String(suffixText),
                            attributes: .init([
                                .font: font,
                                .foregroundColor: NSColor.white
                            ])
                        )
                    )
                } else {
                    lastAttrString.append(AttributedString(String(suffixText)))
                }

                results[results.count - 1] = ParserResult(
                    id: UUID(),
                    attributedString: lastAttrString,
                    isCodeBlock: lastResult.isCodeBlock,
                    codeBlockLanguage: lastResult.codeBlockLanguage
                )

                messages[idx].attributed = AttributedOutput(string: streamText, results: results)
            } else {
                messages[idx].attributed = AttributedOutput(string: streamText, results: [
                    ParserResult(
                        id: UUID(),
                        attributedString: AttributedString(stringLiteral: streamText),
                        isCodeBlock: false,
                        codeBlockLanguage: nil
                    )
                ])
            }
        } catch {
            messages[idx].responseError = error.localizedDescription
        }

        // Check if the parsed string is different than the full string.
        if let currentString = currentOutput?.string, currentString != streamText {
            let output = await parsingTask.parse(text: streamText, isDarkMode: isDarkMode)
            try? Task.checkCancellation()
            messages[idx].attributed = output
        }
    }

    /// Add a user message without flushing the modal text. Use this when there is an active prompt.
    @MainActor
    func setUserMessage(_ text: String) {
        self.clientManager?.appContextManager?.getContext { appContext in
            self.messages.append(
                Message(
                    id: UUID(),
                    text: text,
                    isCurrentUser: true,
                    appContext: appContext
                )
            )
        }
    }

    /// When a user responds, flush the current text to the messages array and add the system and user prompts
    @MainActor
    func addUserMessage(_ text: String, incognito: Bool) {
        self.clientManager?.cancelStreamingTask()

        messages.append(Message(id: UUID(), text: text, isCurrentUser: true))

        self.clientManager?.refine(messages: self.messages, incognitoMode: incognito) { result in
            switch result {
            case .success(let chunk):
                Task {
                    await self.appendText(chunk)
                }
                self.logger.info("Received chunk: \(chunk)")
            case .failure(let error):
                self.setError(error.localizedDescription)
                self.logger.error("An error occurred: \(error)")
            }
        }
    }

    /// Reply to the user
    @MainActor
    func replyToUserMessage(incognito: Bool) {
        if let lastMessage = self.messages.last, let _ = lastMessage.responseError {
            _ = self.messages.popLast()
        }

        self.clientManager?.refine(messages: self.messages, incognitoMode: incognito) { result in
            switch result {
            case .success(let chunk):
                Task {
                    await self.appendText(chunk)
                }
                self.logger.info("Received chunk: \(chunk)")
            case .failure(let error):
                Task {
                    self.setError(error.localizedDescription)
                }
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
        let x = UserDefaults.standard.value(forKey: "toastX") as? CGFloat
        let y = UserDefaults.standard.value(forKey: "toastY") as? CGFloat
        let width = UserDefaults.standard.value(forKey: "toastWidth") as? CGFloat
        let height = UserDefaults.standard.value(forKey: "toastHeight") as? CGFloat

        if let x = x, let y = y, let width = width, let height = height {
            toastWindow?.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        } else {
            toastWindow?.setFrame(NSRect(x: 0, y: 0, width: 500, height: 300), display: true)
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

    func showOnboardingModal() {
        showModal(incognito: false)
        self.clientManager?.onboarding(messages: messages) { result in
            switch result {
            case .success(let chunk):
                Task {
                    await self.appendText(chunk)
                }
                self.logger.info("Received chunk: \(chunk)")
            case .failure(let error):
                DispatchQueue.main.async {
                    self.setError("Something went wrong... please restart the app!")
                }
                self.logger.error("An error occurred: \(error)")
            }
        }
    }

    @objc func windowDidMove(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let origin = movedWindow.frame.origin

            UserDefaults.standard.set(origin.x, forKey: "toastX")
            UserDefaults.standard.set(origin.y, forKey: "toastY")
        }
    }

    @objc func windowDidResize(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let size = movedWindow.frame.size

            UserDefaults.standard.set(size.width, forKey: "toastWidth")
            UserDefaults.standard.set(size.height, forKey: "toastHeight")
        }
    }
}
