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

class ScriptManager {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ScriptManager"
    )

    @AppStorage("scriptDirectoryURL") var scriptDirectoryURL: String?

    private func initScriptDirectory() async throws -> URL {
        let url = try FileManager.default.url(
            for: .applicationScriptsDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )

        scriptDirectoryURL = url.absoluteString
        self.writeScript(to: url)
        return url
    }

    func executeScript() async throws -> NSAppleEventDescriptor {
        var scriptDirURL: URL? = nil
        if let scriptDirectory = scriptDirectoryURL {
            scriptDirURL = URL(string: scriptDirectory)
        } else {
            scriptDirURL = try await initScriptDirectory()
        }

        guard let scriptDirURL = scriptDirURL else {
            logger.error("Script directory could not be set.")
            throw ScriptManagerError.directoryNotSet
        }

        let scriptURL = scriptDirURL.appendingPathComponent("GetActiveTabURL.scpt")

        do {
            let appleScriptTask = try NSUserAppleScriptTask(url: scriptURL)
            return try await appleScriptTask.execute(withAppleEvent: nil)
        } catch {
            self.logger.error("\(error.localizedDescription)")
            throw ScriptManagerError.scriptExecutionFailed
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
            logger.debug("Script saved successfully.")
        } catch {
            logger.debug("Failed to save script: \(error)")
        }
    }
}
