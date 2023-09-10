//
//  LlamaModelManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/4/23.
//

import AppKit
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

    @Published var selectedModel: URL? {
        didSet {
            if let url = selectedModel {
                UserDefaults.standard.set(url.absoluteString, forKey: selectedModelKey)
            } else {
                UserDefaults.standard.removeObject(forKey: selectedModelKey)
            }
        }
    }

    @Published var modelDirectoryURL: URL? {
        didSet {
            if let url = modelDirectoryURL {
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

    init() {
        loadModelDirectoryBookmark()

        // Load saved selected model from UserDefaults
        if let urlString = UserDefaults.standard.string(forKey: selectedModelKey),
           let url = URL(string: urlString) {
            self.loadModel(from: url)
        }

        self.modelFiles = loadModelFiles()
    }

    private func loadModelFiles() -> [URL]? {
        guard let dir = modelDirectoryURL else {
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
                    modelDirectoryURL = resolvedURL
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
            modelDirectoryURL = directoryURL // set only if writing is successful
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

    func stopAccessingDirectory() {
        modelDirectoryURL?.stopAccessingSecurityScopedResource()
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
                    self.selectedModel = url
                    self.currentlyLoadingModel = nil
                }
            } else {
                DispatchQueue.main.async {
                    self.logger.info("model failed to load: \(url.lastPathComponent)")
                    self.isLoading = false
                    self.selectedModel = nil
                    self.currentlyLoadingModel = nil
                    self.showAlert = true
                }
            }
        }
    }

    func unloadModel() {
        self.logger.info("unloading model")
        DispatchQueue.main.async {
            self.selectedModel = nil
            self.model = nil
        }
    }

    func predict(
        payload: RequestPayload,
        streamHandler: @escaping (Result<String, Error>) -> Void
    ) -> Result<String, Error> {
        guard let jsonPayload = encodeToJSONString(from: payload) else {
            let result: Result<String, Error> = .failure(ClientManagerError.badRequest("Encoding error"))
            streamHandler(result)
            return result
        }

        guard let model = self.model else {
            return .failure(ClientManagerError.serverError("Model not found"))
        }

        let prompt = """
        ### Instruction:
        Below is an instruction that describes a task. Write a response that appropriately completes the request.

        ### Input:
        \(jsonPayload)

        ### Response:
        """

        return model.predict(prompt, handler: streamHandler)
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
