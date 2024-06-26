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

class ModalManager: ObservableObject, CanSimulateDictation {
    private let context: NSManagedObjectContext

    @Published var messages: [Message]
    @Published var userIntents: [String]?

    @Published var triggerFocus: Bool
    @Published var isVisible: Bool
    @Published var isPending: Bool

    // Add a Task property to manage task.
    // NOTE: Only one task can be executing at a time!
    var currentTask: Task<Void, Error>? = nil

    @AppStorage("online") var online: Bool = true
    @AppStorage("toastX") var toastX: Double?
    @AppStorage("toastY") var toastY: Double?
    @AppStorage("toastWidth") var toastWidth: Double = 400.0
    @AppStorage("toastHeight") var toastHeight: Double = 400.0
    @AppStorage("hideModalDuringAutopilot") private var hideModalDuringAutopilot: Bool = true
    @AppStorage("isDictationEnabled") private var isDictationEnabled: Bool = true

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ModalManager"
    )

    private let maxIntents = 9

    private let speaker = StreamingSpeechProcessor()

    init(context: NSManagedObjectContext) {
        self.context = context
        self.messages = []
        self.userIntents = nil
        self.triggerFocus = false
        self.isVisible = false
        self.isPending = false
        self.speaker.onFinish = {
            Task {
                guard self.isVisible else {
                    return
                }

                try await self.prepareUserInput()
            }
        }
    }

    // Alphabetize
    // TODO: Inject?
    var clientManager: ClientManager? = nil
    var conversationManager: ConversationManager? = nil
    var functionManager: FunctionManager? = nil
    var intentManager: IntentManager? = nil
    var quickActionManager: QuickActionManager? = nil
    var settingsManager: SettingsManager? = nil
    var specialRecordActor: SpecialRecordActor? = nil  // Needed for special record hook... Pretty nasty

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

    func prepareUserInput() async throws {
        if !self.isVisible {
            await self.showModal()
        }

        await NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(200))

        if self.isDictationEnabled {
            try await Task.sleep(for: .milliseconds(400))
            try await simulateDictation()
        }
    }

    func stopDictation() async throws {
        guard self.isDictationEnabled else {
            return
        }

        try await simulateStopDictation()
    }

    @MainActor
    func cancelTasks() {
        speaker.cancel()
        currentTask?.cancel()
        currentTask = nil
        isPending = false

        // NOTE: Worry about this later... Deal with cancellations of tools
//        var toolCallId: String? = nil
//        var fnCall: FunctionCall? = nil
//        var appContext: AppContext? = nil

        // The next API call will fail if there is a function call but no corresponding tool call.
//        for message in messages {
//            if case .function_call(let functionCall) = message.messageType {
//                fnCall = functionCall
//                toolCallId = functionCall.id
//                appContext = message.appContext
//            } else if case .tool_call(let functionCall) = message.messageType, functionCall.id == toolCallId {
//                // Marking as finished
//                fnCall = nil
//                toolCallId = nil
//                appContext = nil
//            }
//        }
//
//        if let fnCall = fnCall {
//            appendToolError("Function was canceled", functionCall: fnCall, appContext: appContext)
//        }
    }

    @MainActor
    func forceRefresh() {
        currentTask?.cancel()
        currentTask = nil
        messages = []
        isPending = false
        userIntents = nil
    }

    func getQuickAction() -> QuickAction? {
        return messages
            .first(where: { msg in msg.quickActionId != nil })?
            .quickActionId
            .flatMap { quickActionManager?.getById($0) }
    }

    @MainActor
    func setText(
        _ text: String,
        isHidden: Bool = false,
        appContext: AppContext?,
        messageContext: MessageContext? = nil
    ) {
        if !isHidden {
            speaker.processToken(text)
            speaker.flushBuffer(withCallback: true)
        }

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
                        appContext: appContext,
                        messageContext: messageContext
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
                        appContext: appContext,
                        messageContext: messageContext
                    )
                )
            }
        }
    }

    @MainActor
    func appendTool(_ text: String, functionCall: FunctionCall, appContext: AppContext?) {
        for index in messages.indices {
            if case .tool_call(_) = messages[index].messageType {
                messages[index].text = "<pruned>"
            }
        }

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
        isPending = false
        speaker.processToken(responseError)
        speaker.flushBuffer()

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
        speaker.processToken(responseError)
        speaker.flushBuffer()

        if let idx = messages.indices.last, !messages[idx].isCurrentUser, !messages[idx].isHidden {
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
            speaker.processToken(text)
            return
        }

        messages[idx].text += text
        speaker.processToken(text)
    }

    /// Append plan to the AI response. Creates a new message if there is nothing to append to.
    /// NOTE: This is kind of hacky, but the idea is that we can assign a QuickAction ID on message creation,
    /// and we can use the existence of a "quickActionId" to render a "save" button in the UI.
    ///
    /// If you press save, then you can save the Quick Action to your settings.
    @MainActor
    func appendPlan(_ text: String, appContext: AppContext?) async {
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
                        quickActionId: UUID(),
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
                        quickActionId: UUID(),
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

    /// Buffer together consecutive functions
    /// Assume that function calls are immediately followed by their tool calls.
    @MainActor
    func appendFunction(_ text: String, functionCall: FunctionCall, appContext: AppContext?) {
        userIntents = nil
        isPending = true

        if let lastMessage = messages.last,
           case .tool_call(_) = lastMessage.messageType,
           let lastFnCallIndex = messages.lastIndex(where: { isFunctionCall(message: $0) }),
           case .function_call(var functionCalls) = messages[lastFnCallIndex].messageType {

            /// Mutate the function call so that it buffers the actions together.
            /// NOTE: This is for both presentation and token efficiency
            functionCalls.append(functionCall)
            messages[lastFnCallIndex].messageType = .function_call(data: functionCalls)
        } else {
            let id = UUID()
            let date = Date()
            messages.append(Message(
                id: id,
                rootId: id,
                inReplyToId: nil,
                createdAt: date,
                rootCreatedAt: date,
                text: text,
                isCurrentUser: false,
                isHidden: false,
                appContext: appContext,
                messageType: .function_call(data: [functionCall])
            ))
        }
    }

    private func isFunctionCall(message: Message) -> Bool {
        if case .function_call(_) = message.messageType {
            return true
        } else {
            return false
        }
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
    func appendUserImage(_ data: ImageData, appContext: AppContext?) {
        if let lastMessage = messages.last {
            messages.append(
                Message(
                    id: UUID(),
                    rootId: lastMessage.rootId,
                    inReplyToId: lastMessage.id,
                    createdAt: Date(),
                    rootCreatedAt: lastMessage.rootCreatedAt,
                    text: "<image placeholder>",
                    isCurrentUser: true,
                    isHidden: false,
                    appContext: appContext,
                    messageType: .image(data: data)
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
                    text: "<image placeholder>",
                    isCurrentUser: true,
                    isHidden: false,
                    appContext: appContext,
                    messageType: .image(data: data)
                )
            )
        }
    }

    /// Add a user message without flushing the modal text. Use this when there is an active prompt.
    @MainActor
    func setUserMessage(_ text: String, messageType: MessageType = .string, isHidden: Bool = false, appContext: AppContext?) {
        speaker.cancel()

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
    /// When isQuickAction is true, that means that the new text is implicitly a user objective.
    @MainActor
    func addUserMessage(_ text: String, isQuickAction: Bool = false, isHidden: Bool = false, appContext: AppContext?) async {
        speaker.cancel()

        var quickAction: QuickAction? = nil
        if isQuickAction {
            // Look up the quick action by its label or create a new one
            quickAction = await self.quickActionManager?.getOrCreateByLabel(text)
        }

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
                    quickActionId: quickAction?.id,
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
                    quickActionId: quickAction?.id,
                    appContext: appContext
                )
            )
        }

        if userIntents != nil {
            NotificationCenter.default.post(name: .userIntentSent, object: nil)
            userIntents = nil
        }

        isPending = true
        speaker.processToken(text)
        speaker.flushBuffer()

        currentTask?.cancel()
        currentTask = Task {
            do {
                try await reply(quickAction: quickAction)
            } catch let error as ApiError {
                switch error {
                case .functionCallError(let message, let functionCall, let appContext):
                    self.showModal()
                    self.appendToolError(message, functionCall: functionCall, appContext: appContext)
                default:
                    if !self.isVisible {
                        self.showModal()
                    }

                    self.setError(error.errorDescription, appContext: appContext)
                }
            } catch _ as CancellationError {
                if !self.isVisible {
                    self.showModal()
                }

                self.setError("Task was cancelled.", appContext: appContext)
            } catch {
                if !self.isVisible {
                    self.showModal()
                }

                self.setError("Something went wrong: \(error.localizedDescription)", appContext: nil)
            }
        }
    }

    @MainActor
    func setPending(_ _isPending: Bool) {
        self.isPending = _isPending
    }

    private func reply(
        quickAction: QuickAction? = nil,
        prevAppInfo: AppInfo? = nil
    ) async throws {
        try Task.checkCancellation()

        speaker.processToken(NSLocalizedString("Thinking...", comment: ""))
        speaker.flushBuffer()

        if case .focus = self.messages.first?.messageContext {
            let startTime = Date()
            guard let (functionCall, appInfo) = try await self.clientManager?.focus(messages: self.messages) else {
                throw ApiError.functionParsingError("Could not parse function payload.")
            }

            if self.isVisible {
                await self.closeModal()
            }

            print("Focus Response Latency: \(Date().timeIntervalSince(startTime)) seconds")

            // Execute function and add the tool response
            try await self.functionManager?.focusUIElement(functionCall, appInfo: appInfo)

            try Task.checkCancellation()
            print("Focus End-to-End Latency: \(Date().timeIntervalSince(startTime)) seconds")

//            await self.forceRefresh()
            return
        }

        if let (bufferedPayload, appInfo) = try await self.clientManager?.refine(
            messages: self.messages,
            quickActionId: quickAction?.id,
            prevAppInfo: prevAppInfo,
            streamHandler: self.appendText) {

            if bufferedPayload.mode == .text {
                speaker.flushBuffer(withCallback: true)
            } else if bufferedPayload.mode == .function {
                try Task.checkCancellation()
                // Handle Function payloads
                guard let jsonString = bufferedPayload.text,
                      let functionCall = try await functionManager?.parse(jsonString: jsonString) else {
                    throw ApiError.functionParsingError("Could not parse function payload.")
                }

                // Parse arguments and update UI with human readable description.
                let args = try functionCall.parseArgs()
                await self.appendFunction(args.humanReadable, functionCall: functionCall, appContext: appInfo?.appContext)

                speaker.processToken(args.humanReadable)
                speaker.flushBuffer()

                if !hideModalDuringAutopilot {
                    try await Task.safeSleep(for: .seconds(2))  // Add slight delay so that user can see the next action
                }

                if self.isVisible {
                    await self.closeModal()
                }

                // Execute function and add the tool response
                let newAppInfo = try await functionManager?.call(functionCall, appInfo: appInfo)
                try Task.checkCancellation()

                guard let serialized = newAppInfo?.appContext?.serializedUIElement else {
                    throw ApiError.functionCallError(
                        "Failed to get updated state",
                        functionCall: functionCall,
                        appContext: appInfo?.appContext
                    )
                }

                await self.appendTool("Updated State\n\(serialized)", functionCall: functionCall, appContext: newAppInfo?.appContext)

                if !hideModalDuringAutopilot {
                    await self.showModal()
                }

                try Task.checkCancellation()
                try await self.reply(quickAction: quickAction, prevAppInfo: newAppInfo)
            }
        }
    }

    @MainActor
    func updateMessage(index: Int, newContent: String) throws {

        self.messages[index].text = newContent

        if self.messages[index].isCurrentUser {
            // Reissue the message
            let excess = self.messages.count - index - 1
            if excess > 0 {
                self.messages.removeLast(excess)
            }

            isPending = true
            speaker.processToken(NSLocalizedString("Thinking...", comment: ""))
            speaker.flushBuffer()
            userIntents = nil

            currentTask?.cancel()
            currentTask = Task {
                do {
                    try await reply()
                } catch let error as ApiError {
                    switch error {
                    case .badRequest(let message):
                        self.setError(message, appContext: nil)
                    case .serverError(let message):
                        self.setError(message, appContext: nil)
                    case .clientError(let message):
                        self.setError(message, appContext: nil)
                    case .modelNotFound(let message):
                        self.setError(message, appContext: nil)
                    case .modelNotLoaded(let message):
                        self.setError(message, appContext: nil)
                    case .functionParsingError(let message):
                        self.setError(message, appContext: nil)
                    case .functionArgParsingError(let message):
                        self.setError(message, appContext: nil)
                    case .functionCallError(let message, let functionCall, let appContext):
                        self.showModal()
                        self.appendToolError(message, functionCall: functionCall, appContext: appContext)
                    default:
                        self.setError("Something went wrong. \(error.errorDescription)", appContext: nil)
                    }
                } catch _ as CancellationError {
                    if !self.isVisible {
                        self.showModal()
                    }

                    self.setError("Task was cancelled.", appContext: nil)
                } catch {
                    if !self.isVisible {
                        self.showModal()
                    }

                    self.setError("Something went wrong: \(error.localizedDescription)", appContext: nil)
                }
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

        currentTask?.cancel()
        currentTask = Task {
            do {
                try await reply()
            } catch let error as ApiError {
                switch error {
                case .badRequest(let message):
                    self.setError(message, appContext: nil)
                case .serverError(let message):
                    self.setError(message, appContext: nil)
                case .clientError(let message):
                    self.setError(message, appContext: nil)
                case .modelNotFound(let message):
                    self.setError(message, appContext: nil)
                case .modelNotLoaded(let message):
                    self.setError(message, appContext: nil)
                case .functionParsingError(let message):
                    self.setError(message, appContext: nil)
                case .functionArgParsingError(let message):
                    self.setError(message, appContext: nil)
                case .functionCallError(let message, let functionCall, let appContext):
                    self.showModal()
                    self.appendToolError(message, functionCall: functionCall, appContext: appContext)
                default:
                    self.setError("Something went wrong. \(error.errorDescription)", appContext: nil)
                }
            } catch _ as CancellationError {
                if !self.isVisible {
                    self.showModal()
                }

                self.setError("Task was cancelled.", appContext: nil)
            } catch {
                if !self.isVisible {
                    self.showModal()
                }

                self.setError("Something went wrong: \(error.localizedDescription)", appContext: nil)
            }
        }
    }

    @MainActor
    func proposeQuickAction() async throws {
        isPending = true
        speaker.processToken(NSLocalizedString("Thinking...", comment: ""))
        speaker.flushBuffer()

        userIntents = nil

        do {
            guard let (bufferedPayload, _) = try await self.clientManager?.proposeQuickAction(
                messages: self.messages,
                streamHandler: self.appendPlan
            ), let text = bufferedPayload.text else {
                self.setError("Could not genserate a plan", appContext: nil)
                return
            }

            speaker.processToken(text)
            speaker.flushBuffer(withCallback: true)
        } catch {
            self.setError("Could not generate a plan", appContext: nil)
        }

        isPending = false
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
}

extension String {
    func trimmingPrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
