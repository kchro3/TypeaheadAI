//
//  ModalManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/2/23.
//

import AppKit
import SwiftUI
import Foundation
import MarkdownUI
import os.log

enum MessageType: Codable, Equatable {
    case string
    case html(data: String)
    case image(data: ImageData)
    case data(data: Data)
}

// TODO: Add to persistence
struct Message: Codable, Identifiable, Equatable {
    let id: UUID
    var text: String
    let isCurrentUser: Bool
    var responseError: String?
    var messageType: MessageType = .string
    var isTruncated: Bool = true
    var isEdited: Bool = false
}

extension Notification.Name {
    static let userIntentSent = Notification.Name("userIntentSent")
}

class ModalManager: ObservableObject {
    @Published var messages: [Message]
    @Published var userIntents: [String]?

    @Published var triggerFocus: Bool
    @Published var isVisible: Bool
    @Published var online: Bool
    @Published var isPending: Bool

    @AppStorage("toastX") var toastX: Double?
    @AppStorage("toastY") var toastY: Double?
    @AppStorage("toastWidth") var toastWidth: Double = 400.0
    @AppStorage("toastHeight") var toastHeight: Double = 400.0

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ModalManager"
    )

    private let maxMessages = 20

    init() {
        self.messages = []
        self.userIntents = nil
        self.triggerFocus = false
        self.isVisible = false
        self.online = true
        self.isPending = false
    }

    // TODO: Inject?
    var clientManager: ClientManager? = nil
    var promptManager: QuickActionManager? = nil
    var intentManager: IntentManager? = nil
    var settingsManager: SettingsManager? = nil

    var toastWindow: CustomModalWindow?

    func hasText() -> Bool {
        if let lastMessage = messages.last,
                !lastMessage.isCurrentUser {
            return !lastMessage.text.isEmpty
        } else {
            return false
        }
    }

    @MainActor
    func isWindowVisible() -> Bool {
        return toastWindow?.isVisible ?? false
    }

    /// DEPRECATED: This should not be used because it doesn't clear state entirely. Use forceRefresh
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
        isPending = false
        userIntents = nil
    }

    @MainActor
    func forceRefresh() {
        self.clientManager?.cancelStreamingTask()
        self.clientManager?.flushCache()
        self.promptManager?.activePromptID = nil

        messages = []
        isPending = false
        userIntents = nil
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
        isPending = false

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
            userIntents = nil
            isPending = false
            return
        }

        messages[idx].text += text
    }

    @MainActor
    func appendImage(_ image: ImageData, prompt: String, caption: String?) {
        isPending = false
        userIntents = nil

        var placeholder = "<image placeholder>\n"
        placeholder += " - prompt used: \(prompt)"
        if let caption = caption {
            placeholder += " - caption generated: \(caption)"
        }

        messages.append(Message(
            id: UUID(),
            text: placeholder,
            isCurrentUser: false,
            messageType: .image(data: image)
        ))
    }

    @MainActor
    func appendUserImage(_ data: Data, caption: String, ocrText: String) {
        messages.append(Message(
            id: UUID(),
            text: "<image placeholder> caption generated: \(caption); OCR text: \(ocrText)",
            isCurrentUser: true,
            messageType: .data(data: data)
        ))
    }

    /// Add a user message without flushing the modal text. Use this when there is an active prompt.
    @MainActor
    func setUserMessage(_ text: String, messageType: MessageType = .string) {
        isPending = true
        userIntents = nil

        messages.append(
            Message(
                id: UUID(),
                text: text,
                isCurrentUser: true,
                messageType: messageType
            )
        )
    }

    /// When a user responds, flush the current text to the messages array and add the system and user prompts
    /// 
    /// When implicit is true, that means that the new text is implicitly a user objective.
    @MainActor
    func addUserMessage(_ text: String, implicit: Bool = false) {
        self.clientManager?.cancelStreamingTask()

        messages.append(Message(id: UUID(), text: text, isCurrentUser: true))

        if userIntents != nil {
            NotificationCenter.default.post(name: .userIntentSent, object: nil)
            userIntents = nil
        }

        isPending = true
        self.clientManager?.refine(
            messages: self.messages,
            incognitoMode: !online,
            userIntent: implicit ? text : nil,
            streamHandler: { result in

            switch result {
            case .success(let chunk):
                Task {
                    await self.appendText(chunk)
                }
            case .failure(let error as ClientManagerError):
                Task {
                    self.setError(error.localizedDescription)
                }
                self.logger.error("An error occurred: \(error)")
            case .failure(let error):
                Task {
                    self.setError(error.localizedDescription)
                }
                self.logger.error("An error occurred: \(error)")
            }
        }, completion: defaultCompletionHandler)
    }

    @MainActor
    func updateMessage(index: Int, newContent: String) {
        self.messages[index].text = newContent

        if self.messages[index].isCurrentUser {
            // Reissue the message
            let excess = self.messages.count - index - 1
            if excess > 0 {
                self.messages.removeLast(excess)
            }

            isPending = true
            userIntents = nil

            self.clientManager?.refine(
                messages: self.messages,
                incognitoMode: !online,
                streamHandler: defaultHandler,
                completion: defaultCompletionHandler
            )
        }
    }

    /// Reply to the user
    /// If refresh, then pop the previous message before responding.
    @MainActor
    func replyToUserMessage(refresh: Bool) {
        isPending = true
        userIntents = nil

        if refresh, let lastMessage = self.messages.last {
            if let _ = lastMessage.responseError {
                _ = self.messages.popLast()
            } else if case .string = lastMessage.messageType {
                _ = self.messages.popLast()
            } else if case .html = lastMessage.messageType {
                _ = self.messages.popLast()
            }
        }

        self.clientManager?.refine(
            messages: self.messages,
            incognitoMode: !online,
            streamHandler: defaultHandler,
            completion: defaultCompletionHandler
        )
    }

    @MainActor
    func setUserIntents(intents: [String]) {
        isPending = false
        userIntents = intents
    }

    @MainActor
    func appendUserIntents(intents: [String]) {
        userIntents?.append(contentsOf: intents)
    }

    @MainActor
    func closeModal() {
        toastWindow?.close()
        isVisible = false
    }

    @MainActor
    func showModal() {
        toastWindow?.close()

        // Create the visual effect view with frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow

        // Create the content view
        let contentView = ModalView(
            showModal: .constant(true),
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
        toastWindow?.modalManager = self

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
            hostingView.topAnchor.constraint(equalTo: baseView.topAnchor, constant: -22), // Offset by the size of the menu bar
            hostingView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor)
        ])

        // Set the x, y coordinates and the size to the user's last preference or the center by default
        if let x = toastX, let y = toastY {
            toastWindow?.setFrame(NSRect(x: x, y: y, width: toastWidth, height: toastHeight), display: true)
        } else {
            toastWindow?.setFrame(NSRect(x: 0, y: 0, width: toastWidth, height: toastHeight), display: true)
            toastWindow?.center()
        }

        toastWindow?.titlebarAppearsTransparent = true
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

        self.isVisible = true
    }

    @objc func windowDidMove(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let origin = movedWindow.frame.origin

            DispatchQueue.main.async {
                self.toastX = origin.x
                self.toastY = origin.y
            }
        }
    }

    @objc func windowDidResize(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let size = movedWindow.frame.size

            DispatchQueue.main.async {
                self.toastWidth = size.width
                self.toastHeight = size.height
            }
        }
    }

    func defaultCompletionHandler(result: Result<ChunkPayload, Error>) {
        switch result {
        case .success(let success):
            guard let text = success.text else {
                return
            }

            switch success.mode ?? .text {
            case .text:
                return // no-op
            case .image:
                Task {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.isPending = true
                    }

                    do {
                        if let data = text.data(using: .utf8),
                           let imageRequest = try? JSONDecoder().decode(ImageRequestPayload.self, from: data),
                           let imageData = try await self.clientManager?.generateImage(payload: imageRequest) {
                            if self.online,
                               let data = Data(base64Encoded: imageData.image) {
                                let captionPayload = await self.clientManager?.captionImage(tiffData: data)
                                await self.appendImage(imageData, prompt: imageRequest.prompt, caption: captionPayload?.caption)
                            } else {
                                await self.appendImage(imageData, prompt: imageRequest.prompt, caption: nil)
                            }
                        }
                    } catch {
                        await self.setError(error.localizedDescription)
                    }
                }
            case .function:
                Task {
                    do {
                        try await Functions.parseAndCallFunction(jsonString: text, modalManager: self)
                    } catch {
                        await self.setError(error.localizedDescription)
                    }
                }
            }
        case .failure(let error as ClientManagerError):
            switch error {
            case .badRequest(let message):
                Task {
                    await self.setError(message)
                }
            default:
                Task {
                    await self.setError("Something went wrong. Please try again.")
                    self.logger.error("Something went wrong.")
                }
            }
        case .failure(let error):
            Task {
                self.logger.error("Error: \(error.localizedDescription)")
                await self.setError(error.localizedDescription)
            }
        }
    }

    func defaultHandler(result: Result<String, Error>) async {
        switch result {
        case .success(let chunk):
            await self.appendText(chunk)
        case .failure(let error as ClientManagerError):
            self.logger.error("Error: \(error.localizedDescription)")
            switch error {
            case .badRequest(let message):
                await self.setError(message)
            case .serverError(let message):
                await self.setError(message)
            case .clientError(let message):
                await self.setError(message)
            default:
                await self.setError("Something went wrong. Please try again.")
            }
        case .failure(let error):
            self.logger.error("Error: \(error.localizedDescription)")
            await self.setError(error.localizedDescription)
        }
    }
}

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
