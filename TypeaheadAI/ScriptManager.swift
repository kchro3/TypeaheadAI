//
//  ScriptManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/27/23.
//

import AppKit
import Foundation
import SwiftUI
import os.log

enum ScriptName: String, Identifiable {
    case getActiveTabURL = "GetActiveTabURL"
    case screencaptureActiveWindow = "SCActiveWindow"

    var id: String { "\(self.rawValue).scpt" }
}

class ScriptManager {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ScriptManager"
    )

    private var scriptDirectoryURL: URL?

    init() {
        Task {
            scriptDirectoryURL = try await initScriptDirectory()
        }
    }

    // Lazily write to script
    private func initScriptDirectory() async throws -> URL {
        let url = try FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        self.writeScripts(to: url)
        return url
    }

    func executeScript(script: ScriptName) async throws -> NSAppleEventDescriptor {
        guard let scriptDirURL = scriptDirectoryURL else {
            logger.error("Script directory could not be set.")
            throw ScriptManagerError.directoryNotSet
        }

        let scriptURL = scriptDirURL.appendingPathComponent(script.id)

        do {
            let appleScriptTask = try NSUserAppleScriptTask(url: scriptURL)
            return try await appleScriptTask.execute(withAppleEvent: nil)
        } catch {
            self.logger.error("\(error.localizedDescription)")
            throw ScriptManagerError.scriptExecutionFailed
        }
    }

    private func writeScripts(to directoryURL: URL) {
        let chromeURLScript = """
        tell application "Google Chrome"
            return URL of active tab of front window
        end tell
        """

        let activeWindowScreenshotScript = """
        tell application "System Events"
            set frontmostProcess to first process where it is frontmost
            set windowID to id of window 1 of frontmostProcess
        end tell

        do shell script "screencapture -l" & windowID & " ~/Desktop/screenshot.png"
        """

        do {
            // Write the chrome URL script
            try chromeURLScript.write(
                to: directoryURL.appendingPathComponent(ScriptName.getActiveTabURL.id),
                atomically: true,
                encoding: .utf8
            )

            // Write the screencapture script
            try activeWindowScreenshotScript.write(
                to: directoryURL.appendingPathComponent(ScriptName.screencaptureActiveWindow.id),
                atomically: true,
                encoding: .utf8
            )

            logger.debug("Script saved successfully.")
        } catch {
            logger.debug("Failed to save script: \(error)")
        }
    }
}

enum ScriptManagerError: Error {
    case directoryNotSet
    case scriptExecutionFailed
    case unknownError
}

extension ScriptManagerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .directoryNotSet:
            return "Script directory is not set."
        case .scriptExecutionFailed:
            return "Failed to execute script."
        case .unknownError:
            return "An unknown error occurred."
        }
    }
}
