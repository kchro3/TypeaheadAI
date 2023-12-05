//
//  LlamaModelManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/4/23.
//

import AppKit
import SwiftUI
import Foundation
import os.log

class LlamaModelManager: ObservableObject {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "LlamaModelManager"
    )

    @Published var modelFiles: [URL]? {
        didSet {
            if let files = self.modelFiles {
                logger.info("Found \(files.count) .gguf files: \(files.map { $0.lastPathComponent })")
            } else {
                logger.debug("No .gguf files found.")
            }
        }
    }

    @AppStorage("modelDirectoryBookmark") private var modelDirectoryBookmark: Data?
    @AppStorage("selectedModel") private var selectedModelURL: URL?
    @AppStorage("modelDirectory") private var directoryURL: URL? {
        didSet {
            if let url = directoryURL {
                guard url.startAccessingSecurityScopedResource() else {
                    logger.debug("Failed to start accessing security-scoped resource.")
                    return
                }

                saveDirectoryBookmark(from: url)
            }
        }
    }

    private var model: LlamaWrapper?

    @MainActor
    func setModelDirectory(_ url: URL) {
        directoryURL = url
        selectedModelURL = nil  // Unset the current model
    }

    @MainActor
    func load() async throws {
        loadModelDirectoryBookmark()

        // Load saved selected model from UserDefaults
        self.modelFiles = loadModelFiles()

        if let urlString = selectedModelURL {
            try await self.loadModel(from: urlString)
        }
    }

    deinit {
        directoryURL?.stopAccessingSecurityScopedResource()
    }

    private func loadModelFiles() -> [URL]? {
        guard let dir = directoryURL else {
            logger.error("No model directory set.")
            return nil
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "gguf" }
                .filter { $0.lastPathComponent != "ggml-vocab-llama.gguf" }
        } catch {
            logger.error("Error listing files in directory: \(error)")
            return nil
        }
    }

    private func loadModelDirectoryBookmark() {
        if let bookmarkData = modelDirectoryBookmark {
            var isBookmarkStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isBookmarkStale)
                if isBookmarkStale {
                    // Handle stale bookmarks (rare)
                } else {
                    directoryURL = resolvedURL
                }
            } catch {
                logger.error("Failed to resolve security-scoped bookmark: \(error)")
            }
        } else {
            // If bookmark is missing, prompt for model directory
            promptForModelDirectory()
        }
    }

    private func promptForModelDirectory() {
        DispatchQueue.global().async {
            var modelDir: URL? = nil
            do {
                modelDir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            } catch {
                self.logger.error("Error obtaining documentDirectory: \(error)")
            }

            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.title = "Choose the Documents Directory"
                panel.message = "Choose a directory for TypeaheadAI to save LLMs in."
                panel.canCreateDirectories = true
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.prompt = "Open"

                if let dir = modelDir {
                    panel.directoryURL = dir
                }

                let result = panel.runModal()

                if result == .OK, let selectedURL = panel.urls.first {
                    self.writeReadMe(to: selectedURL)
                    self.saveDirectoryBookmark(from: selectedURL)
                }
            }
        }
    }

    private func writeReadMe(to directoryURL: URL) {
        let contents = """
        # TypeaheadAI LLM directory
        You may delete this file. This is to validate that TypeaheadAI has
        permissions to write to this directory.
        """

        let readmeURL = directoryURL.appendingPathComponent("README.md")

        do {
            try contents.write(to: readmeURL, atomically: true, encoding: .utf8)
            self.directoryURL = directoryURL // set only if writing is successful
            logger.debug("readme saved successfully.")
        } catch {
            logger.error("Failed to save readme: \(error)")
        }
    }

    private func saveDirectoryBookmark(from directoryURL: URL) {
        do {
            modelDirectoryBookmark = try directoryURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            logger.error("Failed to create security-scoped bookmark: \(error)")
        }
    }

    func loadModel(from url: URL) async throws {
        self.model = LlamaWrapper(url)

        guard let _ = self.model?.isLoaded() else {
            throw ClientManagerError.modelNotLoaded("Model could not be loaded")
        }

        self.logger.info("model loaded successfully: \(url.lastPathComponent)")
    }

    func unloadModel() {
        self.logger.info("unloading model")
        DispatchQueue.main.async {
            self.selectedModelURL = nil
            self.model = nil
        }
    }

    /// Disable suggest intents for offline mode
    func suggestIntents(
        payload: RequestPayload
    ) async throws -> SuggestIntentsPayload {
        return SuggestIntentsPayload(intents: [])
    }
//        guard let model = self.model else {
//            throw ClientManagerError.modelNotFound("Model not found")
//        }
//
//        var payloadCopy = payload
//        payloadCopy.messages = []
//        guard let jsonPayload = encodeToJSONString(from: payloadCopy) else {
//            throw ClientManagerError.badRequest("Encoding error")
//        }
//
//        let prompt = """
//        ### Instruction:
//        Below is an instruction that describes a task. Predict three possible user intents based on the copied text and context, and return them as a tab-separated, unquoted string.
//
//        ### Input:
//        \(jsonPayload)
//
//        ## Response:
//
//        """
//
//        print(prompt)
//
//        let result = await model.predict2(prompt)
//        switch result {
//        case .success(let data):
//            if let values = data.text?.split(separator: ",") {
//                return SuggestIntentsPayload(intents: values.map { String($0) })
//            } else {
//                return SuggestIntentsPayload(intents: [])
//            }
//        case .failure(let error):
//            throw error
//        }
//    }

    func predict(
        payload: RequestPayload,
        streamHandler: @escaping (Result<String, Error>, AppContext?) async -> Void
    ) async throws {
        guard let model = model else {
            throw ClientManagerError.modelNotLoaded("No model loaded.")
        }

        var payloadCopy = payload
        payloadCopy.messages = []

        guard let jsonPayload = encodeToJSONString(from: payloadCopy) else {
            throw ClientManagerError.badRequest("Encoding error")
        }

        var refinements = ""
        if let messages = payload.messages {
            for message in messages {
                if message.isCurrentUser {
                    refinements += """
                    \(message.text)

                    ### Response:
                    """
                } else {
                    refinements += """
                    \(message.text)

                    ### Input:

                    """
                }
            }
        }

        let prompt = """
        ### Instruction:
        Below is an instruction that describes a task. Write a response that appropriately completes the request.

        ### Input:
        \(jsonPayload)

        ### Response:
        \(refinements)

        """

        print(prompt)

        do {
            for try await token in model.predict(prompt) {
                await streamHandler(.success(token), nil)
            }
        } catch {
            throw ClientManagerError.modelFailed(error.localizedDescription)
        }
    }

    private func encodeToJSONString<T: Codable>(from object: T) -> String? {
        let encoder = JSONEncoder()

        do {
            let jsonData = try encoder.encode(object)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            self.logger.error("Encoding failed: \(error.localizedDescription)")
        }

        return nil
    }
}
