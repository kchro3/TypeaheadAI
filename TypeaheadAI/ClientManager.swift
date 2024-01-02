//
//  ClientManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/20/23.
//

import AppKit
import CoreData
import Foundation
import os.log
import SwiftUI
import Supabase

class ClientManager: ObservableObject, CanGetUIElements {
    var llamaModelManager: LlamaModelManager? = nil
    var promptManager: QuickActionManager? = nil
    var appContextManager: AppContextManager? = nil
    var intentManager: IntentManager? = nil
    var historyManager: HistoryManager? = nil
    var supabaseManager: SupabaseManager? = nil

    private let session: URLSession

    private let version: String = "v10"
    private let validFinishReasons: [String] = [
        "stop",
        "function_call",
        "tool_calls",
    ]

    @AppStorage("online") private var online: Bool = true
    @AppStorage("isWebSearchEnabled") private var isWebSearchEnabled: Bool = true
    @AppStorage("isAutopilotEnabled") private var isAutopilotEnabled: Bool = true

    #if DEBUG
//    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/v2/get_stream")!
//    private let apiImage = URL(string: "https://typeahead-ai.fly.dev/v2/get_image")!
//    private let apiIntents = URL(string: "https://typeahead-ai.fly.dev/v2/suggest_intents")!
//    private let apiImageCaptions = URL(string: "https://typeahead-ai.fly.dev/v2/get_image_caption")!
//    private let apiLatest = URL(string: "https://typeahead-ai.fly.dev/v3/latest")!
//    private let apiFeedback = URL(string: "https://typeahead-ai.fly.dev/v2/feedback")!
    private let apiUrlStreaming = URL(string: "http://localhost:8080/v2/get_stream")!
    private let apiImage = URL(string: "http://localhost:8080/v2/get_image")!
    private let apiIntents = URL(string: "http://localhost:8080/v2/suggest_intents")!
    private let apiImageCaptions = URL(string: "http://localhost:8080/v2/get_image_caption")!
    private let apiLatest = URL(string: "http://localhost:8080/v3/latest")!
    private let apiFeedback = URL(string: "http://localhost:8080/v2/feedback")!

    #else
    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/v2/get_stream")!
    private let apiImage = URL(string: "https://typeahead-ai.fly.dev/v2/get_image")!
    private let apiIntents = URL(string: "https://typeahead-ai.fly.dev/v2/suggest_intents")!
    private let apiImageCaptions = URL(string: "https://typeahead-ai.fly.dev/v2/get_image_caption")!
    private let apiLatest = URL(string: "https://typeahead-ai.fly.dev/v3/latest")!
    private let apiFeedback = URL(string: "https://typeahead-ai.fly.dev/v2/feedback")!
    #endif

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Add a Task property to manage the streaming task
    @Published var isExecuting: Bool = false
    var currentStreamingTask: Task<Void, Error>? = nil

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getLatestVersion() async -> AppVersion? {
        do {
            let (data, _) = try await URLSession.shared.data(from: apiLatest)
            return try? JSONDecoder().decode(AppVersion.self, from: data)
        } catch {
            self.logger.error("\(error.localizedDescription)")
            return nil
        }
    }

    func sendFeedback(feedback: String, timeout: TimeInterval = 30) async throws {
        guard let uuid = try? await supabaseManager?.client.auth.session.user.id else {
            throw ClientManagerError.signInRequired("Must be signed in to share feedback!")
        }
        
        let payload = FeedbackPayload(uuid: uuid, feedback: feedback)

        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Request was malformed...")
        }

        var urlRequest = URLRequest(url: self.apiFeedback, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await self.session.data(for: urlRequest)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ClientManagerError.serverError("Something went wrong...")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ClientManagerError.serverError(errorResponse.detail)
            } else {
                throw ClientManagerError.serverError("Something went wrong...")
            }
        }
    }

    /// This used to call the suggest intents API, but it's too slow.
    /// This is using CoreData instead of remotely fetching the user intents.
    func suggestIntents(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String?,
        userBio: String,
        userLang: String,
        copiedText: String,
        messages: [Message],
        history: [Message]?,
        appContext: AppContext?,
        timeout: TimeInterval = 30
    ) async throws -> SuggestIntentsPayload? {
        let uuid: UUID? = try? await supabaseManager?.client.auth.session.user.id
        let payload = RequestPayload(
            uuid: uuid ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            username: username,
            userFullName: userFullName,
            userObjective: userObjective,
            userBio: userBio,
            userLang: userLang,
            copiedText: copiedText,
            messages: self.sanitizeMessages(messages),
            history: history,
            appContext: appContext,
            version: version
        )

        if !online {
            // Incognito mode doesn't support this yet
            return nil
        } else {
            return nil  // Disable for now, wasting tokens.

            guard let httpBody = try? JSONEncoder().encode(payload) else {
                throw ClientManagerError.badRequest("Request was malformed...")
            }

            var urlRequest = URLRequest(url: self.apiIntents, timeoutInterval: timeout)
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = httpBody
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let (data, resp) = try await self.session.data(for: urlRequest)

            guard let httpResponse = resp as? HTTPURLResponse else {
                throw ClientManagerError.serverError("Something went wrong...")
            }

            guard 200...299 ~= httpResponse.statusCode else {
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ClientManagerError.serverError(errorResponse.detail)
                } else {
                    throw ClientManagerError.serverError("Something went wrong...")
                }
            }

            return try JSONDecoder().decode(SuggestIntentsPayload.self, from: data)
        }
    }

    /// Refine the currently request
    func refine(
        messages: [Message],
        quickActionId: UUID? = nil,
        prevAppInfo: AppInfo? = nil,
        timeout: TimeInterval = 120,
        streamHandler: @escaping (Result<String, Error>, AppInfo?) async -> Void,
        completion: @escaping (Result<ChunkPayload, Error>, AppInfo?) async -> Void
    ) async throws {
        var appInfo: AppInfo? = nil
        if let prevAppInfo = prevAppInfo {
            // Reuse the previous app info (specifically when the app info was extracted from a function call).
            appInfo = prevAppInfo
        } else {
            appInfo = try await appContextManager?.getActiveAppInfo()

            // Serialize the UIElement
            if isAutopilotEnabled {
                let (uiElement, elementMap) = getUIElements(appContext: appInfo?.appContext)
                if let serializedUIElement = uiElement?.serialize(
                    excludedActions: ["AXScrollToVisible", "AXCancel", "AXRaise"]
                ) {
                    appInfo?.appContext?.serializedUIElement = serializedUIElement
                    appInfo?.elementMap = elementMap
                }
            }
        }

        try Task.checkCancellation()

        // The first message is copiedText if it isn't associated with a Quick Action.
        // NOTE: The logic for determining if something is associated with a Quick Action
        // is janky - we check if there are "user intents" set. This is because we
        // set user intents when the user opens a new chat window or after the user
        // smart-copies something. Therefore, if the first message does not have a
        // Quick Action, it must be a copied text.
        var copiedText: String? = nil
        if let firstMessage = messages.first, firstMessage.quickActionId == nil {
            copiedText = firstMessage.text
        }

        var history: [Message]? = nil
        // NOTE: Need to fetch again in case the Quick Action has been edited
        let quickAction: QuickAction? = messages
            .first(where: { $0.quickActionId != nil })
            .flatMap { $0.quickActionId }
            .flatMap { self.promptManager?.getById($0) }

        try Task.checkCancellation()
        if let quickAction = quickAction,
           let appContext = appInfo?.appContext,
           let copiedText = copiedText {
            history = self.historyManager?.fetchHistoryEntriesAsMessages(limit: 10, appContext: appContext, quickActionID: quickAction.id)

            await self.intentManager?.addIntentEntry(
                prompt: quickAction.prompt,
                copiedText: copiedText,
                appContext: appContext
            )
        }

        try Task.checkCancellation()
        await self.sendStreamRequest(
            id: UUID(),
            username: NSUserName(),
            userFullName: NSFullUserName(),
            userObjective: quickAction?.details ?? "",
            userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
            userLang: Locale.preferredLanguages.first ?? "",
            copiedText: copiedText ?? "",
            messages: self.sanitizeMessages(messages),
            history: history,
            appInfo: appInfo,
            timeout: timeout,
            streamHandler: streamHandler,
            completion: completion
        )

        // Add in any other relevant metadata
        NotificationCenter.default.post(
            name: .chatComplete,
            object: nil,
            userInfo: [
                "messages": messages
            ]
        )
    }

    /// Sends a request to the server with the given parameters and listens for a stream of data.
    ///
    /// - Parameters:
    ///   - Same as sendRequest
    ///   - streamHandler: A closure to be executed for each chunk of data received.
    @MainActor
    func sendStreamRequest(
        id: UUID,
        username: String,
        userFullName: String,
        userObjective: String?,
        userBio: String,
        userLang: String,
        copiedText: String,
        messages: [Message],
        history: [Message]?,
        appInfo: AppInfo?,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>, AppInfo?) async -> Void,
        completion: @escaping (Result<ChunkPayload, Error>, AppInfo?) async -> Void
    ) async {
        cancelStreamingTask()
        isExecuting = true
        currentStreamingTask = Task.init { [weak self] in
            let uuid = try? await self?.supabaseManager?.client.auth.session.user.id
            let payload = RequestPayload(
                uuid: uuid ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
                username: username,
                userFullName: userFullName,
                userObjective: userObjective,
                userBio: userBio,
                userLang: userLang,
                copiedText: copiedText,
                messages: self?.sanitizeMessages(messages),
                history: history,
                appContext: appInfo?.appContext,
                version: self?.version,
                isWebSearchEnabled: self?.isWebSearchEnabled,
                isAutopilotEnabled: self?.isAutopilotEnabled,
                apps: appInfo?.apps.values.map { $0.bundleIdentifier }
            )

            if !(self?.online ?? true) {
                guard let llamaModelManager = self?.llamaModelManager else {
                    return
                }

                do {
                    try await llamaModelManager.predict(payload: payload, streamHandler: streamHandler)
                } catch {
                    await streamHandler(.failure(error), appInfo)
                }
            } else {
                do {
                    let stream = try self?.performStreamOnlineTask(
                        payload: payload,
                        timeout: timeout,
                        appInfo: appInfo,
                        completion: completion
                    )

                    try Task.checkCancellation()
                    guard let stream = stream else {
                        self?.logger.debug("Failed to get stream")
                        return
                    }

                    for try await text in stream {
                        try Task.checkCancellation()
                        await streamHandler(.success(text), appInfo)
                    }
                } catch {
                    await streamHandler(.failure(error), appInfo)
                }
            }

            await MainActor.run {
                self?.currentStreamingTask = nil
                self?.isExecuting = false
            }
        }
    }

    func generateImage(
        payload: ImageRequestPayload,
        timeout: TimeInterval = 30.0
    ) async throws -> ImageData? {
        var payloadCopy = payload
        payloadCopy.version = version
        guard let httpBody = try? JSONEncoder().encode(payloadCopy) else {
            throw ClientManagerError.badRequest("Bad request format")
        }

        var urlRequest = URLRequest(url: self.apiImage, timeoutInterval: timeout)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = httpBody
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, resp) = try await self.session.data(for: urlRequest)

        guard let httpResponse = resp as? HTTPURLResponse else {
            throw ClientManagerError.serverError("Something went wrong...")
        }

        guard 200...299 ~= httpResponse.statusCode else {
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw ClientManagerError.serverError(errorResponse.detail)
            } else {
                throw ClientManagerError.serverError("Something went wrong...")
            }
        }

        let response = try JSONDecoder().decode(ImageResponse.self, from: data)
        return response.data[0]
    }

    private func performStreamOnlineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        appInfo: AppInfo?,
        completion: @escaping (Result<ChunkPayload, Error>, AppInfo?) async -> Void
    ) throws -> AsyncThrowingStream<String, Error> {
        guard let httpBody = try? JSONEncoder().encode(payload) else {
            throw ClientManagerError.badRequest("Encoding error")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return AsyncThrowingStream { continuation in
            Task {
                var urlRequest = URLRequest(url: self.apiUrlStreaming, timeoutInterval: timeout)
                urlRequest.httpMethod = "POST"
                urlRequest.httpBody = httpBody
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")

                guard let (data, resp) = try? await self.session.bytes(for: urlRequest) else {
                    let error = ClientManagerError.serverError("Couldn't connect to server... Retry or use in offline mode.")
                    continuation.finish(throwing: error)
                    return
                }

                guard let httpResponse = resp as? HTTPURLResponse else {
                    let error = ClientManagerError.serverError("Something went wrong...")
                    continuation.finish(throwing: error)
                    return
                }

                guard 200...299 ~= httpResponse.statusCode else {
                    var buffer = Data()
                    var error = ClientManagerError.serverError("Something went wrong...")
                    for try await byte in data {
                        buffer.append(byte)
                    }
                    if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: buffer) {
                        error = ClientManagerError.serverError(errorResponse.detail)
                    }

                    continuation.finish(throwing: error)
                    return
                }

                // NOTE: This is complicated, but we want to support a case where the AI is responding to a user request
                // but also making a function call. To support this, if a payload is something other than .text,
                // it is a special payload and should be cached separately.
                // In the future, we can think about how to support completions with a full response, but worry about that later.
                var bufferedPayload: ChunkPayload = ChunkPayload(finishReason: nil)
                for try await line in data.lines {
                    try Task.checkCancellation()

                    guard let data = line.data(using: .utf8),
                          let response = try? decoder.decode(ChunkPayload.self, from: data) else {
                        let error = ClientManagerError.serverError("Failed to parse response...")
                        continuation.finish(throwing: error)
                        return
                    }

                    if let text = response.text {
                        switch response.mode ?? .text {
                        case .text:
                            continuation.yield(text)
                            if bufferedPayload.mode != .image {
                                bufferedPayload.text = (bufferedPayload.text ?? "") + text
                                bufferedPayload.mode = .text
                            }
                        case .image:
                            bufferedPayload = response
                        case .function:
                            bufferedPayload = response
                        }
                    } else if let finishReason = response.finishReason,
                              !validFinishReasons.contains(finishReason) {
                        let error = ClientManagerError.serverError("Stream is incomplete. Finished with error: \(finishReason)")
                        continuation.finish(throwing: error)
                        return
                    }
                }

                await completion(.success(bufferedPayload), appInfo)
                continuation.finish()
            }
        }
    }

    @MainActor
    func cancelStreamingTask() {
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
        isExecuting = false
    }

    private func sanitizeMessages(_ messages: [Message]) -> [Message] {
        return messages.map { originalMessage in
            var messageCopy = originalMessage
            messageCopy.appContext?.serializedUIElement = nil
            return messageCopy
        }
    }
}

struct RequestPayload: Codable {
    let uuid: UUID
    var username: String
    var userFullName: String
    var userObjective: String?
    var userBio: String
    var userLang: String
    var copiedText: String
    var messages: [Message]?
    var history: [Message]?
    var appContext: AppContext?
    var version: String?
    var isWebSearchEnabled: Bool?
    var isAutopilotEnabled: Bool?
    var apps: [String]?
}

/// https://replicate.com/stability-ai/sdxl
struct ImageRequestPayload: Codable {
    let prompt: String
    let style: [String]?
    var version: String?
}

struct ErrorResponse: Codable {
    let detail: String
}

/// Copied from https://github.com/MarcoDotIO/OpenAIKit/blob/main/Sources/OpenAIKit/Types/Enums/Images/ImageData.swift
public enum ImageData: Codable, Equatable {
    enum CodingKeys: String, CodingKey {
        case url
        case b64Json = "b64_json"
    }

    /// The image is stored as a URL string.
    case url(String)

    /// The image is stored as a Base64 binary.
    case b64Json(String)

    /// The image itself.
    public var image: String {
        switch self {
        case let .b64Json(b64Json): return b64Json
        case let .url(url): return url
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let url = try? container.decode(String.self, forKey: .url) {
            if let data = try? Data(contentsOf: URL(string: url)!) {
                let base64Json = data.base64EncodedString()
                self = .b64Json(base64Json)
                return
            }
        }

        let b64Associate = try container.decode(String.self, forKey: .b64Json)
        self = .b64Json(b64Associate)
    }

    func toURL() -> URL {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("image-\(Date()).png")
        // Write the image data to the temporary file
        try? Data(base64Encoded: self.image)?.write(to: tempURL)
        return tempURL
    }
}

/// Copied from https://github.com/MarcoDotIO/OpenAIKit/blob/main/Sources/OpenAIKit/Types/Structs/Schemas/Images/ImageResponse.swift
public struct ImageResponse: Codable {
    /// The creation date of the response.
    public let created: Int

    /// The data sent within the response containing either `URL` or `Base64` data.
    public let data: [ImageData]
}

struct AppVersion: Codable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int
    let url: String?
}

struct ResponsePayload: Codable {
    let textToPaste: String
    let assumedIntent: String
    let choices: [String]
}

enum Mode: String, Codable {
    case text
    case image
    case function
}

struct ChunkPayload: Codable {
    var text: String?
    var mode: Mode?
    let finishReason: String?
}

enum ClientManagerError: LocalizedError {
    case badRequest(_ message: String)
    case retriesExceeded(_ message: String)
    case clientError(_ message: String)
    case serverError(_ message: String)
    case appError(_ message: String)
    case networkError(_ message: String)
    case corruptedDataError(_ message: String)
    case signInRequired(_ message: String)

    // LLaMA errors
    case modelNotFound(_ message: String)
    case modelNotLoaded(_ message: String)
    case modelDirectoryNotAuthorized(_ message: String)
    case modelFailed(_ message: String)

    var errorDescription: String {
        switch self {
        case .badRequest(let message): return message
        case .retriesExceeded(let message): return message
        case .clientError(let message): return message
        case .serverError(let message): return message
        case .appError(let message): return message
        case .networkError(let message): return message
        case .corruptedDataError(let message): return message
        case .signInRequired(let message): return message

        // LLaMA model errors
        case .modelNotFound(let message): return message
        case .modelNotLoaded(let message): return message
        case .modelDirectoryNotAuthorized(let message): return message
        case .modelFailed(let message): return message
        }
    }
}

struct SuggestIntentsPayload: Codable {
    let intents: [String]
}

struct FeedbackPayload: Codable {
    let uuid: UUID
    let feedback: String
}
