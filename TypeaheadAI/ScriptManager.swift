//
//  ScriptManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/27/23.
//

import AppKit
import Foundation
import os.log

enum ScriptManagerError: Error {
    case directoryNotSet
    case scriptExecutionFailed
    case bookmarkResolutionFailed
    case unknownError
}

extension ScriptManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .directoryNotSet:
            return "Script directory is not set."
        case .scriptExecutionFailed:
            return "Failed to execute script."
        case .bookmarkResolutionFailed:
            return "Failed to resolve security-scoped bookmark."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}

class ScriptManager {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ScriptManager"
    )

    private var scriptDirectoryURL: URL? {
        didSet {
            if let url = scriptDirectoryURL {
                let success = url.startAccessingSecurityScopedResource()
                if !success {
                    logger.debug("Failed to start accessing security-scoped resource.")
                }
            }
        }
    }

    init() {
        loadScriptDirectoryBookmark()
    }

    func executeScript(completion: @escaping (NSAppleEventDescriptor?, ScriptManagerError?) -> Void) {
        guard let directoryURL = scriptDirectoryURL else {
            logger.debug("Script directory is not set.")
            completion(nil, ScriptManagerError.directoryNotSet)
            return
        }

        let scriptURL = directoryURL.appendingPathComponent("GetActiveTabURL.scpt")

        do {
            let appleScriptTask = try NSUserAppleScriptTask(url: scriptURL)
            appleScriptTask.execute(withAppleEvent: nil) { (result, error) in
                if let _ = error {
                    self.logger.debug("Error: \(ScriptManagerError.scriptExecutionFailed)")
                    completion(nil, ScriptManagerError.scriptExecutionFailed)
                } else {
                    completion(result, nil)
                }
            }
        } catch {
            logger.debug("Failed to execute script: \(ScriptManagerError.scriptExecutionFailed)")
            completion(nil, ScriptManagerError.scriptExecutionFailed)
        }
    }

    func promptForScriptDirectory() {
        DispatchQueue.global().async {
            var appScriptsDir: URL? = nil
            do {
                appScriptsDir = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            } catch {
                self.logger.debug("Error obtaining applicationScriptsDirectory: \(error)")
            }

            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.title = "Choose the Application Scripts Directory"
                panel.message = "Open this directory to authorize TypeaheadAI to save scripts here. Only needs to be done once."
                panel.canCreateDirectories = true
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false
                panel.prompt = "Open"

                if let dir = appScriptsDir {
                    panel.directoryURL = dir
                }

                let result = panel.runModal()

                if result == .OK, let selectedURL = panel.urls.first {
                    self.writeScript(to: selectedURL)
                    self.saveScriptDirectoryBookmark(from: selectedURL)
                }
            }
        }
    }

    private func writeScript(to directoryURL: URL) {
        let appleScript = """
        tell application "Google Chrome"
            return URL of active tab of front window
        end tell
        """

        let scriptFileURL = directoryURL.appendingPathComponent("GetActiveTabURL.scpt")

        do {
            try appleScript.write(to: scriptFileURL, atomically: true, encoding: .utf8)
            scriptDirectoryURL = directoryURL // set only if writing is successful
            logger.debug("Script saved successfully.")
        } catch {
            logger.debug("Failed to save script: \(error)")
        }
    }

    private func saveScriptDirectoryBookmark(from directoryURL: URL) {
        do {
            let bookmarkData = try directoryURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: "scriptDirectoryBookmark2")
        } catch {
            logger.debug("Failed to create security-scoped bookmark: \(error)")
        }
    }

    private func loadScriptDirectoryBookmark() {
        if let bookmarkData = UserDefaults.standard.data(forKey: "scriptDirectoryBookmark2") {
            var isBookmarkStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isBookmarkStale)
                if isBookmarkStale {
                    // Handle stale bookmarks (rare)
                } else {
                    scriptDirectoryURL = resolvedURL
                }
            } catch {
                logger.debug("Failed to resolve security-scoped bookmark: \(error)")
            }
        } else {
            // If bookmark is missing, prompt for script directory
            promptForScriptDirectory()
        }
    }

    func stopAccessingDirectory() {
        scriptDirectoryURL?.stopAccessingSecurityScopedResource()
    }
}
