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

class ClientManager: ObservableObject {
    var llamaModelManager: LlamaModelManager? = nil
    var promptManager: QuickActionManager? = nil
    var appContextManager: AppContextManager? = nil
    var intentManager: IntentManager? = nil
    var historyManager: HistoryManager? = nil
    var supabaseManager: SupabaseManager? = nil

    private let session: URLSession

    private let version: String = "v4"

    #if DEBUG
//    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/v2/get_stream")!
//    private let apiImage = URL(string: "https://typeahead-ai.fly.dev/v2/get_image")!
//    private let apiIntents = URL(string: "https://typeahead-ai.fly.dev/v2/suggest_intents")!
//    private let apiImageCaptions = URL(string: "https://typeahead-ai.fly.dev/v2/get_image_caption")!
//    private let apiLatest = URL(string: "https://typeahead-ai.fly.dev/v2/latest")!
    private let apiUrlStreaming = URL(string: "http://localhost:8080/v2/get_stream")!
    private let apiImage = URL(string: "http://localhost:8080/v2/get_image")!
    private let apiIntents = URL(string: "http://localhost:8080/v2/suggest_intents")!
    private let apiImageCaptions = URL(string: "http://localhost:8080/v2/get_image_caption")!
    private let apiLatest = URL(string: "http://localhost:8080/v2/latest")!
    #else
    private let apiUrlStreaming = URL(string: "https://typeahead-ai.fly.dev/v2/get_stream")!
    private let apiImage = URL(string: "https://typeahead-ai.fly.dev/v2/get_image")!
    private let apiIntents = URL(string: "https://typeahead-ai.fly.dev/v2/suggest_intents")!
    private let apiImageCaptions = URL(string: "https://typeahead-ai.fly.dev/v2/get_image_caption")!
    private let apiLatest = URL(string: "https://typeahead-ai.fly.dev/v2/latest")!
    #endif

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ClientManager"
    )

    // Add a Task property to manage the streaming task
    @Published var currentStreamingTask: Task<Void, Error>? = nil

    private var cached: (String, String?)? = nil

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getActivePrompt() -> String? {
        return self.promptManager?.getActivePrompt()
    }

    func checkUpdates() async -> AppVersion? {
        do {
            let (data, _) = try await URLSession.shared.data(from: apiLatest)
            return try? JSONDecoder().decode(AppVersion.self, from: data)
        } catch {
            self.logger.error("\(error.localizedDescription)")
            return nil
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
        incognitoMode: Bool,
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

        // NOTE: Cache the payload so we know what text was copied
        self.cacheResponse(nil, for: payload)

        if incognitoMode {
            // Incognito mode doesn't support this yet
            return nil
        } else {
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

    /// Easier to use this wrapper function.
    func predict(
        id: UUID,
        copiedText: String,
        incognitoMode: Bool,
        history: [Message]? = nil,
        userObjective: String? = nil,
        timeout: TimeInterval = 30,
        stream: Bool = false,
        streamHandler: @escaping (Result<String, Error>) async -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) async throws {
        self.logger.info("incognito: \(incognitoMode)")
        // If objective is not specified in the request, fall back on the active prompt.
        let objective = userObjective ?? self.promptManager?.getActivePrompt()

        guard let appCtxManager = appContextManager else {
            self.logger.error("Something is wrong with the initialization")
            completion(.failure(ClientManagerError.appError("Something went wrong.")))
            return
        }

        let appContext = try await appCtxManager.getActiveAppInfo()
        await self.sendStreamRequest(
            id: id,
            username: NSUserName(),
            userFullName: NSFullUserName(),
            userObjective: objective,
            userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
            userLang: Locale.preferredLanguages.first ?? "",
            copiedText: copiedText,
            messages: [],
            history: history,
            appContext: appContext,
            incognitoMode: incognitoMode,
            streamHandler: streamHandler,
            completion: completion
        )
    }

    /// Refine the currently cached request
    func refine(
        messages: [Message],
        incognitoMode: Bool,
        userIntent: String? = nil,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) async -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) {
        self.logger.info("incognito: \(incognitoMode)")
        if let (key, _) = cached,
           let data = key.data(using: .utf8),
           let payload = try? JSONDecoder().decode(RequestPayload.self, from: data) {
            Task {
                var history: [Message]? = nil
                var quickAction: QuickAction? = nil
                if let userIntent = userIntent {
                    // NOTE: Check if the user intent is also a Quick Action
                    quickAction = self.promptManager?.getByLabel(userIntent)
                    if let quickActionID = quickAction?.id {
                        // NOTE: This is probably a stupid way of managing the state
                        await self.promptManager?.setActivePrompt(id: quickActionID)

                        // Create a few-shot prompt from smart-copy-paste history
                        history = self.historyManager?.fetchHistoryEntriesAsMessages(limit: 10, appContext: payload.appContext, quickActionID: quickActionID)
                    } else {
                        quickAction = await self.promptManager?.addPrompt(userIntent)
                        history = self.intentManager?.fetchIntentsAsMessages(
                            limit: 10,
                            appContext: payload.appContext
                        )
                    }

                    // NOTE: We cached the copiedText earlier
                    await self.intentManager?.addIntentEntry(
                        prompt: userIntent,
                        copiedText: payload.copiedText,
                        appContext: payload.appContext
                    )
                }

                await self.sendStreamRequest(
                    id: UUID(),
                    username: payload.username,
                    userFullName: payload.userFullName,
                    userObjective: quickAction?.details ?? payload.userObjective,
                    userBio: payload.userBio,
                    userLang: payload.userLang,
                    copiedText: payload.copiedText,
                    messages: self.sanitizeMessages(messages),
                    history: history,
                    appContext: payload.appContext,
                    incognitoMode: incognitoMode,
                    streamHandler: streamHandler,
                    completion: completion
                )
            }
        } else {
            logger.error("No cached request to refine")
            Task {
                await self.sendStreamRequest(
                    id: UUID(),
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: "",
                    userBio: UserDefaults.standard.string(forKey: "bio") ?? "",
                    userLang: Locale.preferredLanguages.first ?? "",
                    copiedText: "",
                    messages: self.sanitizeMessages(messages),
                    history: nil,
                    appContext: nil,
                    incognitoMode: incognitoMode,
                    streamHandler: streamHandler,
                    completion: completion
                )
            }
        }
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
        appContext: AppContext?,
        incognitoMode: Bool,
        timeout: TimeInterval = 30,
        streamHandler: @escaping (Result<String, Error>) async -> Void,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
    ) async {
        cancelStreamingTask()
        currentStreamingTask = Task.detached { [weak self] in
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
                appContext: appContext,
                version: self?.version
            )

            if let output = self?.getCachedResponse(for: payload) {
                await streamHandler(.success(output))
                return
            }

            if incognitoMode {
                if let result: Result<ChunkPayload, Error> = await self?.performStreamOfflineTask(
                    payload: payload, timeout: timeout, streamHandler: streamHandler) {

                    completion(result)

                    // Cache successful requests
                    switch result {
                    case .success(let output):
                        self?.cacheResponse(output.text, for: payload)
                        break
                    case .failure(_):
                        self?.cacheResponse(nil, for: payload)
                        break
                    }
                } else {
                    completion(.failure(ClientManagerError.appError("Something went wrong...")))
                }
            } else {
                do {
                    let stream = try self?.performStreamOnlineTask(
                        payload: payload,
                        timeout: timeout,
                        completion: { result in
                            completion(result)

                            // Cache successful response
                            switch result {
                            case .success(let output):
                                self?.cacheResponse(output.text, for: payload)
                            case .failure(let error):
                                self?.logger.error("\(error.localizedDescription)")
                            }
                        }
                    )

                    guard let stream = stream else {
                        self?.logger.debug("Failed to get stream")
                        return
                    }

                    for try await text in stream {
                        self?.logger.debug("stream: \(text)")
                        await streamHandler(.success(text))
                    }
                } catch {
                    self?.cacheResponse(nil, for: payload)
                    await streamHandler(.failure(error))
                }
            }
        }

        try? await currentStreamingTask?.value
        currentStreamingTask = nil
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

    func captionImage(
        tiffData: Data,
        timeout: TimeInterval = 30.0
    ) async -> ImageCaptionPayload? {
        let bitmap = NSBitmapImageRep(data: tiffData)
        let jpegData = bitmap?.representation(using: .jpeg, properties: [:])

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        var urlRequest = URLRequest(url: apiImageCaptions)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.httpBody = jpegData
        do {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let payload = try decoder.decode(ImageCaptionPayload.self, from: data)
            return payload
        } catch {
            self.logger.error("\(error.localizedDescription)")
            return nil
        }
    }

    private func performStreamOnlineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        completion: @escaping (Result<ChunkPayload, Error>) -> Void
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
                    guard let data = line.data(using: .utf8),
                          let response = try? decoder.decode(ChunkPayload.self, from: data) else {
                        let error = ClientManagerError.serverError("Failed to parse response...")
                        continuation.finish(throwing: error)
                        completion(.failure(error))
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
                        }
                    } else if let finishReason = response.finishReason,
                              finishReason != "stop" {
                        let error = ClientManagerError.serverError("Stream is incomplete. Finished with error: \(finishReason)")
                        continuation.finish(throwing: error)
                        completion(.failure(error))
                        return
                    }
                }
                
                completion(.success(bufferedPayload))
                continuation.finish()
            }
        }
    }

    private func performStreamOfflineTask(
        payload: RequestPayload,
        timeout: TimeInterval,
        streamHandler: @escaping (Result<String, Error>) async -> Void
    ) async -> Result<ChunkPayload, Error> {
        guard let modelManager = self.llamaModelManager else {
            return .failure(ClientManagerError.appError("Model Manager not found"))
        }

        return await modelManager.predict(payload: payload, streamHandler: streamHandler)
    }

    @MainActor
    func cancelStreamingTask() {
        currentStreamingTask?.cancel()
        currentStreamingTask = nil
    }

    private func generateCacheKey(from payload: RequestPayload) -> String? {
        let encoder = JSONEncoder()

        do {
            let jsonData = try encoder.encode(payload)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            self.logger.error("Encoding failed: \(error.localizedDescription)")
        }

        return nil
    }

    private func getCachedResponse(for requestPayload: RequestPayload) -> String? {
        guard let cacheKey = generateCacheKey(from: requestPayload) else {
            return nil
        }

        if let (key, val) = cached {
            return (key == cacheKey) ? val : nil
        } else {
            return nil
        }
    }

    private func cacheResponse(_ response: String?, for requestPayload: RequestPayload) {
        if let cacheKey = generateCacheKey(from: requestPayload) {
            self.logger.debug("Overwrite cached request")
            cached = (cacheKey, response)
        }
    }

    private func sanitizeMessages(_ messages: [Message]) -> [Message] {
        return messages.map { originalMessage in
            var messageCopy = originalMessage
            messageCopy.attributed = nil
            messageCopy.messageType = .string
            return messageCopy
        }
    }

    func flushCache() {
        cached = nil
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
    let build: Int
}

struct ResponsePayload: Codable {
    let textToPaste: String
    let assumedIntent: String
    let choices: [String]
}

enum Mode: String, Codable {
    case text
    case image
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
        }
    }
}

struct SuggestIntentsPayload: Codable {
    let intents: [String]
}
