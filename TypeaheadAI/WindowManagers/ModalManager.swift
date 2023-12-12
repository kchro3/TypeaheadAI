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

extension Notification.Name {
    static let userIntentSent = Notification.Name("userIntentSent")
}

class ModalManager: ObservableObject {
    private let context: NSManagedObjectContext

    @Published var messages: [Message]
    @Published var userIntents: [String]?

    @Published var triggerFocus: Bool
    @Published var isVisible: Bool
    @Published var isPending: Bool

    @AppStorage("online") var online: Bool = true
    @AppStorage("toastX") var toastX: Double?
    @AppStorage("toastY") var toastY: Double?
    @AppStorage("toastWidth") var toastWidth: Double = 400.0
    @AppStorage("toastHeight") var toastHeight: Double = 400.0

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ModalManager"
    )

    private let maxIntents = 9
    private let maxMessages = 20
    private let functionManager = FunctionManager()

    init(context: NSManagedObjectContext) {
        self.context = context
        self.messages = []
        self.userIntents = nil
        self.triggerFocus = false
        self.isVisible = false
        self.isPending = false
    }

    // Alphabetize
    // TODO: Inject?
    var clientManager: ClientManager? = nil
    var conversationManager: ConversationManager? = nil
    var intentManager: IntentManager? = nil
    var promptManager: QuickActionManager? = nil
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

    @MainActor
    func forceRefresh() throws {
        self.clientManager?.cancelStreamingTask()
        self.clientManager?.flushCache()
        self.promptManager?.activePromptID = nil

        messages = []
        isPending = false
        userIntents = nil
    }

    @MainActor
    func setText(_ text: String, isHidden: Bool = false, appContext: AppContext?) {
        if !isHidden,
           let idx = messages.indices.last,
           !messages[idx].isCurrentUser {
            messages[idx].text += text
        } else {
            if let lastMessage = messages.last {
                messages.append(
                    Message(
                        id: UUID(),
                        rootId: lastMessage.rootId,
                        inReplyToId: lastMessage.id,
                        createdAt: Date(),
                        rootCreatedAt: lastMessage.rootCreatedAt,
                        text: text,
                        isCurrentUser: false,
                        isHidden: isHidden,
                        appContext: appContext
                    )
                )
            } else {
                let id = UUID()
                let date = Date()
                messages.append(
                    Message(
                        id: id,
                        rootId: id,
                        inReplyToId: nil,
                        createdAt: date,
                        rootCreatedAt: date,
                        text: text,
                        isCurrentUser: false,
                        isHidden: isHidden,
                        appContext: appContext
                    )
                )
            }
        }
    }

    @MainActor
    func appendTool(_ text: String, functionCall: FunctionCall, appContext: AppContext?) {
        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: text,
                    isCurrentUser: false,
                    isHidden: true,
                    appContext: appContext,
                    messageType: .tool_call(data: functionCall)
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: text,
                    isCurrentUser: false,
                    isHidden: true,
                    appContext: appContext,
                    messageType: .tool_call(data: functionCall)
                )
            )
        }
    }

    @MainActor
    func appendToolError(_ responseError: String, functionCall: FunctionCall, appContext: AppContext?) {
        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: "",
                    isCurrentUser: false,
                    isHidden: false,
                    appContext: appContext,
                    responseError: responseError,
                    messageType: .tool_call(data: functionCall)
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: "",
                    isCurrentUser: false,
                    isHidden: false,
                    appContext: appContext,
                    responseError: responseError,
                    messageType: .tool_call(data: functionCall)
                )
            )
        }
    }

    /// Set an error message.
    @MainActor
    func setError(_ responseError: String, isHidden: Bool = false, appContext: AppContext?) {
        isPending = false

        if let idx = messages.indices.last, !messages[idx].isCurrentUser {
            messages[idx].responseError = responseError
        } else {
            if let lastMessage = messages.last {
                messages.append(
                    Message(
                        id: UUID(),
                        rootId: lastMessage.rootId,
                        inReplyToId: lastMessage.id,
                        createdAt: Date(),
                        rootCreatedAt: lastMessage.rootCreatedAt,
                        text: "",
                        isCurrentUser: false,
                        isHidden: isHidden,
                        appContext: appContext,
                        responseError: responseError
                    )
                )
            } else {
                let id = UUID()
                let date = Date()
                messages.append(
                    Message(
                        id: id,
                        rootId: id,
                        inReplyToId: nil,
                        createdAt: date,
                        rootCreatedAt: date,
                        text: "",
                        isCurrentUser: false,
                        isHidden: isHidden,
                        appContext: appContext,
                        responseError: responseError
                    )
                )
            }
        }
    }

    /// Append text to the AI response. Creates a new message if there is nothing to append to.
    @MainActor
    func appendText(_ text: String, appContext: AppContext?) async {
        guard let idx = messages.indices.last, !messages[idx].isCurrentUser, !messages[idx].isHidden else {
            // If the AI response doesn't exist yet, create one.
            if let lastMessage = messages.last {
                messages.append(
                    Message(
                        id: UUID(),
                        rootId: lastMessage.rootId,
                        inReplyToId: lastMessage.id,
                        createdAt: Date(),
                        rootCreatedAt: lastMessage.rootCreatedAt,
                        text: text,
                        isCurrentUser: false,
                        isHidden: false,
                        appContext: appContext
                    )
                )
            } else {
                let id = UUID()
                let date = Date()
                messages.append(
                    Message(
                        id: id,
                        rootId: id,
                        inReplyToId: nil,
                        createdAt: date,
                        rootCreatedAt: date,
                        text: text,
                        isCurrentUser: false,
                        isHidden: false,
                        appContext: appContext
                    )
                )
            }
            userIntents = nil
            isPending = false
            return
        }

        messages[idx].text += text
    }

    @MainActor
    func appendFunction(_ text: String, functionCall: FunctionCall, appContext: AppContext?) {
        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: text,
                    isCurrentUser: false,
                    isHidden: false,
                    appContext: appContext,
                    messageType: .function_call(data: functionCall)
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: text,
                    isCurrentUser: false,
                    isHidden: false,
                    appContext: appContext,
                    messageType: .function_call(data: functionCall)
                )
            )
        }

        userIntents = nil
        isPending = false
    }

    @MainActor
    func appendImage(_ image: ImageData, prompt: String, caption: String?, appContext: AppContext?) {
        isPending = false
        userIntents = nil

        var placeholder = "<image placeholder>\n"
        placeholder += " - prompt used: \(prompt)"
        if let caption = caption {
            placeholder += " - caption generated: \(caption)"
        }

        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: placeholder,
                    isCurrentUser: false,
                    isHidden: false,
                    appContext: appContext,
                    messageType: .image(data: image)
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: placeholder,
                    isCurrentUser: false,
                    isHidden: false,
                    appContext: appContext,
                    messageType: .image(data: image)
                )
            )
        }
    }

    @MainActor
    func appendUserImage(_ data: Data, caption: String, ocrText: String, appContext: AppContext?) {
        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: "<image placeholder> caption generated: \(caption); OCR text: \(ocrText)",
                    isCurrentUser: false,
                    isHidden: true,
                    appContext: appContext,
                    messageType: .data(data: data)
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: "<image placeholder> caption generated: \(caption); OCR text: \(ocrText)",
                    isCurrentUser: false,
                    isHidden: true,
                    appContext: appContext,
                    messageType: .data(data: data)
                )
            )
        }
    }

    /// Add a user message without flushing the modal text. Use this when there is an active prompt.
    @MainActor
    func setUserMessage(_ text: String, messageType: MessageType = .string, isHidden: Bool = false, appContext: AppContext?) {
        isPending = true
        userIntents = nil

        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: text,
                    isCurrentUser: true,
                    isHidden: isHidden,
                    appContext: appContext,
                    messageType: messageType
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: text,
                    isCurrentUser: true,
                    isHidden: isHidden,
                    appContext: appContext,
                    messageType: messageType
                )
            )
        }
    }

    /// When a user responds, flush the current text to the messages array and add the system and user prompts
    /// 
    /// When implicit is true, that means that the new text is implicitly a user objective.
    @MainActor
    func addUserMessage(_ text: String, implicit: Bool = false, isHidden: Bool = false, appContext: AppContext?) async throws {
        self.clientManager?.cancelStreamingTask()

        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: text,
                    isCurrentUser: true,
                    isHidden: isHidden,
                    appContext: appContext
                )
            )
        } else {
            let id = UUID()
            let date = Date()
            messages.append(
                Message(
                    id: id,
                    rootId: id,
                    inReplyToId: nil,
                    createdAt: date,
                    rootCreatedAt: date,
                    text: text,
                    isCurrentUser: true,
                    isHidden: isHidden,
                    appContext: appContext
                )
            )
        }

        if userIntents != nil {
            NotificationCenter.default.post(name: .userIntentSent, object: nil)
            userIntents = nil
        }

        isPending = true
        Task {
            try await self.clientManager?.refine(
                messages: self.messages,
                incognitoMode: !online,
                userIntent: implicit ? text : nil,
                streamHandler: defaultHandler,
                completion: defaultCompletionHandler
            )
        }
    }

    @MainActor
    func updateMessage(index: Int, newContent: String) async throws {
        self.messages[index].text = newContent

        if self.messages[index].isCurrentUser {
            // Reissue the message
            let excess = self.messages.count - index - 1
            if excess > 0 {
                self.messages.removeLast(excess)
            }

            isPending = true
            userIntents = nil

            Task {
                try await self.clientManager?.refine(
                    messages: self.messages,
                    incognitoMode: !online,
                    streamHandler: defaultHandler,
                    completion: defaultCompletionHandler
                )
            }
        }
    }

    /// Rewind to a certain message index
    @MainActor
    func rewindTo(index: Int) async throws {
        guard index >= 0, index < messages.count else {
            self.logger.error("Not a valid index \(index) out of \(self.messages.count)")
            return
        }

        self.messages = Array(self.messages.prefix(index))
    }

    /// Reply to the user
    /// If refresh, then pop the previous message before responding.
    @MainActor
    func replyToUserMessage() async throws {
        isPending = true
        userIntents = nil

        Task {
            try await self.clientManager?.refine(
                messages: self.messages,
                incognitoMode: !online,
                streamHandler: defaultHandler,
                completion: defaultCompletionHandler
            )
        }
    }

    @MainActor
    func continueReplying() async throws {
        isPending = true
        userIntents = nil

        Task {
            try await self.clientManager?.refine(
                messages: self.messages,
                incognitoMode: !online,
                streamHandler: defaultHandler,
                completion: defaultCompletionHandler
            )
        }
    }

    @MainActor
    func setUserIntents(intents: [String]) {
        isPending = false

        if intents.count > maxIntents {
            userIntents = Array(intents.prefix(upTo: maxIntents))
        } else {
            userIntents = intents
        }
    }

    @MainActor
    func appendUserIntents(intents: [String]) {
        if (userIntents?.count ?? 0) + intents.count > maxIntents {
            let upTo = maxIntents - (userIntents?.count ?? 0)  // If there are 10 max & 3 intents, we should only add up to 7 new intents
            userIntents?.append(contentsOf: intents.prefix(upTo: upTo))
        } else {
            userIntents?.append(contentsOf: intents)
        }
    }

    @MainActor
    func load(rootId: UUID) throws {
        if let messages = try conversationManager?.getConversation(rootId: rootId) {
            try conversationManager?.saveConversation(messages: self.messages)
            self.messages = messages
        }
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
        .environment(\.managedObjectContext, context)

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
                .titled,
                .miniaturizable
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

    @MainActor
    func defaultCompletionHandler(result: Result<ChunkPayload, Error>, appInfo: AppInfo?) async {
        switch result {
        case .success(let success):
            guard let text = success.text else {
                return
            }

            switch success.mode ?? .text {
            case .text:
                return // no-op
            case .image:
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
                            self.appendImage(imageData, prompt: imageRequest.prompt, caption: captionPayload?.caption, appContext: appInfo?.appContext)
                        } else {
                            self.appendImage(imageData, prompt: imageRequest.prompt, caption: nil, appContext: appInfo?.appContext)
                        }
                    }
                } catch {
                    self.setError(error.localizedDescription, appContext: appInfo?.appContext)
                }
            case .function:
                await functionManager.parseAndCallFunction(jsonString: text, appInfo: appInfo, modalManager: self)
            }
        case .failure(let error as ClientManagerError):
            switch error {
            case .badRequest(let message):
                self.setError(message, appContext: appInfo?.appContext)
            default:
                self.setError("Something went wrong. Please try again.", appContext: appInfo?.appContext)
                self.logger.error("Something went wrong.")
            }
        case .failure(let error):
            self.logger.error("Error: \(error.localizedDescription)")
            self.setError(error.localizedDescription, appContext: appInfo?.appContext)
        }
    }

    func defaultHandler(result: Result<String, Error>, appInfo: AppInfo?) async {
        switch result {
        case .success(let chunk):
            await self.appendText(chunk, appContext: appInfo?.appContext)
        case .failure(let error as ClientManagerError):
            self.logger.error("Error: \(error.localizedDescription)")
            switch error {
            case .badRequest(let message):
                await self.setError(message, appContext: appInfo?.appContext)
            case .serverError(let message):
                await self.setError(message, appContext: appInfo?.appContext)
            case .clientError(let message):
                await self.setError(message, appContext: appInfo?.appContext)
            case .modelNotFound(let message):
                await self.setError(message, appContext: appInfo?.appContext)
            case .modelNotLoaded(let message):
                await self.setError(message, appContext: appInfo?.appContext)
            default:
                await self.setError("Something went wrong. Please try again.", appContext: appInfo?.appContext)
            }
        case .failure(let error):
            self.logger.error("Error: \(error.localizedDescription)")
            await self.setError(error.localizedDescription, appContext: appInfo?.appContext)
        }
    }
}

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
