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

    deinit {
        scriptDirectoryURL?.stopAccessingSecurityScopedResource()
    }

    func executeScript() async throws -> NSAppleEventDescriptor? {
        guard let directoryURL = scriptDirectoryURL else {
            logger.debug("Script directory is not set.")
            throw ScriptManagerError.directoryNotSet
        }

        let scriptURL = directoryURL.appendingPathComponent("GetActiveTabURL.scpt")
        self.logger.debug("Executing script at \(scriptURL)")

        do {
            let appleScriptTask = try NSUserAppleScriptTask(url: scriptURL)
            return try await appleScriptTask.execute(withAppleEvent: nil)
        } catch {
            self.logger.error("\(error.localizedDescription)")
            throw ScriptManagerError.scriptExecutionFailed
        }
    }

    /// DEPRECATED: Prefer the async throws API
    func executeScript(completion: @escaping (NSAppleEventDescriptor?, ScriptManagerError?) -> Void) {
        guard let directoryURL = scriptDirectoryURL else {
            logger.debug("Script directory is not set.")
            completion(nil, ScriptManagerError.directoryNotSet)
            return
        }

        let scriptURL = directoryURL.appendingPathComponent("GetActiveTabURL.scpt")
        self.logger.debug("Executing script at \(scriptURL)")

        do {
            let appleScriptTask = try NSUserAppleScriptTask(url: scriptURL)
            appleScriptTask.execute(withAppleEvent: nil) { (result, error) in
                if let error = error, error.localizedDescription.contains("-1743") {
                    // Check if the user has opted to not see the warning again
                    if !UserDefaults.standard.bool(forKey: "DontShowAppleEventWarning") {
                        self.showAppleEventPermissionDialog()
                    }
                    completion(nil, ScriptManagerError.scriptExecutionFailed)
                } else if let _ = error {
                    self.logger.error("\(error?.localizedDescription ?? "")")
                    completion(nil, ScriptManagerError.scriptExecutionFailed)
                } else {
                    completion(result, nil)
                }
            }
        } catch let error {
            self.logger.error("\(error.localizedDescription)")
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
                panel.message = "Choose an install location"
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

    private func showAppleEventPermissionDialog() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Permission Required"
            alert.informativeText = "TypeaheadAI wants permission to get the active URL. Click 'Open Preferences' to go to the Security & Privacy pane where you can grant permission."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Preferences")
            alert.addButton(withTitle: "Cancel")
            alert.showsSuppressionButton = true // Allow the user to not show this alert again

            let modalResult = alert.runModal()

            // Save the user's choice to not show the alert again
            if let suppressionButton = alert.suppressionButton, suppressionButton.state == .on {
                UserDefaults.standard.set(true, forKey: "DontShowAppleEventWarning")
            }

            switch modalResult {
            case .alertFirstButtonReturn:
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            case .alertSecondButtonReturn:
                // Handle cancel action if needed
                break
            default:
                break
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
}
