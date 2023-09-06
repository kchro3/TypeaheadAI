//
//  LlamaModelManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/4/23.
//

import AppKit
import Foundation
import os.log
import llmfarm_core

class LlamaModelManager: ObservableObject {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "LlamaModelManager"
    )

    private let bookmarkKey = "modelDirectoryBookmark"
    private let selectedModelKey = "selectedModelKey"
    private var ai: AI?

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

    init() {
        loadModelDirectoryBookmark()

        // Load saved selected model from UserDefaults
        if let urlString = UserDefaults.standard.string(forKey: selectedModelKey),
           let url = URL(string: urlString) {
            selectedModel = url
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
        let ai = AI(_modelPath: url.relativePath, _chatName: "chat")
        var params: ModelContextParams = .default
        params.use_metal = true
        params.parts = 256

        ai.loadModel(.LLama_gguf, contextParams: params)
        ai.model.promptFormat = .LLaMa_QA

        DispatchQueue.main.async {
            self.ai = ai
            self.selectedModel = url
        }

        self.logger.info("loading \(url.lastPathComponent)")
    }

    func unloadModel() {
        DispatchQueue.main.async {
            self.ai = nil
            self.selectedModel = nil
        }
    }

    func predict(
        request: RequestPayload,
        streamHandler: @escaping (String?, Error?) -> Void
    ) throws {
        guard let jsons = encodeToJSONString(from: request) else {
            return
        }

        let prompt = """
        <s>[INST] <<SYS>>
        You are a predictive writing tool. The user has copied some text ("copiedText") and wants to autocomplete a response.
        Given a user, the current app ("activeAppName"), and the text they have copied, predict what the user wants to write, and your verbatim response will be injected as text input to the current app.
        The user may provide a "user_objective" to hint what should be done with the text. Respond as the user.
        <</SYS>>

        {"copiedText":"my name is jeff","activeAppName":"Google Chrome","user_objective":"translate to japanese"} [/INST] 私の名前はジェフです。</s>
        <s>[INST] {"copiedText":"factorial","activeAppName":"Google Chrome","url": "https://leetcode.com","user_objective":"python"} [/INST] def factorial(n):\n    if n == 1:\n        return 1\n     return factorial(n-1) * n</s>
        <s>[INST] {"copiedText":"Dear Jeff, thank you for your email. Ben","url":"https://gmail.com","activeAppName":"Google Chrome"} [/INST] Dear Ben,\nThank you for your email.\nJeff</s>
        <s>[INST] \(jsons) [/INST]
        """

        print("sample params: \(self.ai!.model.sampleParams)")
        print("context params: \(self.ai!.model.contextParams)")
        self.logger.info("\(prompt)")

        _ = try self.ai?.model.predict(
            prompt, { (chunk, _) in
                self.logger.info("chunk: \(chunk)")
                streamHandler(chunk, nil)
                return false
            })
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
