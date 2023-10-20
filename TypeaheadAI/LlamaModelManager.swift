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

    private let bookmarkKey = "modelDirectoryBookmark"
    private let selectedModelKey = "selectedModelKey"

    @Published var modelFiles: [URL]? {
        didSet {
            if let files = self.modelFiles {
                logger.info("Found \(files.count) .gguf files: \(files.map { $0.lastPathComponent })")
            } else {
                logger.debug("No .gguf files found.")
            }
        }
    }

    @AppStorage("selectedModel") private var selectedModelURL: URL?
    @AppStorage("modelDirectory") private var directoryURL: URL? {
        didSet {
            if let url = directoryURL {
                let success = url.startAccessingSecurityScopedResource()
                if !success {
                    logger.debug("Failed to start accessing security-scoped resource.")
                }
            }
        }
    }

    @Published var isLoading: Bool = false
    @Published var currentlyLoadingModel: URL?
    @Published var showAlert: Bool = false

    private var model: LlamaWrapper?

    func load() {
        loadModelDirectoryBookmark()

        // Load saved selected model from UserDefaults
        if let urlString = selectedModelURL {
            self.loadModel(from: urlString)
        }

        self.modelFiles = loadModelFiles()
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
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
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
            let bookmarkData = try directoryURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
        } catch {
            logger.error("Failed to create security-scoped bookmark: \(error)")
        }
    }

    func loadModel(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.model = LlamaWrapper(url)

            guard let model = self.model else {
                return
            }

            if (model.isLoaded()) {
                DispatchQueue.main.async {
                    self.logger.info("model loaded successfully: \(url.lastPathComponent)")
                    self.isLoading = false
                    self.selectedModelURL = url
                    self.currentlyLoadingModel = nil
                }
            } else {
                DispatchQueue.main.async {
                    self.logger.info("model failed to load: \(url.lastPathComponent)")
                    self.isLoading = false
                    self.selectedModelURL = nil
                    self.currentlyLoadingModel = nil
                    self.showAlert = true
                }
            }
        }
    }

    func unloadModel() {
        self.logger.info("unloading model")
        DispatchQueue.main.async {
            self.selectedModelURL = nil
            self.model = nil
        }
    }

    func suggestIntents(
        payload: RequestPayload
    ) async throws -> SuggestIntentsPayload {
        guard let model = self.model else {
            throw ClientManagerError.appError("Model not found")
        }

        var payloadCopy = payload
        payloadCopy.messages = []
        guard let jsonPayload = encodeToJSONString(from: payloadCopy) else {
            throw ClientManagerError.badRequest("Encoding error")
        }

        let prompt = """
        ### Instruction:
        Below is an instruction that describes a task. Predict three possible user intents based on the copied text and context, and return them as a tab-separated, unquoted string.

        ### Input:
        \(jsonPayload)

        ## Response:

        """

        print(prompt)

        let result = await model.predict(prompt)
        switch result {
        case .success(let data):
            if let values = data.text?.split(separator: ",") {
                return SuggestIntentsPayload(intents: values.map { String($0) })
            } else {
                return SuggestIntentsPayload(intents: [])
            }
        case .failure(let error):
            throw error
        }
    }

    func predict(
        payload: RequestPayload,
        streamHandler: @escaping (Result<String, Error>) async -> Void
    ) async -> Result<ChunkPayload, Error> {
        var payloadCopy = payload
        payloadCopy.messages = []

        guard let jsonPayload = encodeToJSONString(from: payloadCopy) else {
            let error = ClientManagerError.badRequest("Encoding error")
            await streamHandler(.failure(error))
            return .failure(error)
        }

        guard let model = self.model else {
            let error = ClientManagerError.serverError("Model not found")
            await streamHandler(.failure(error))
            return .failure(error)
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

        return await model.predict(prompt, handler: streamHandler)
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
