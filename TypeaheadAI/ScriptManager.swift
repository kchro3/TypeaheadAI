//
//  ScriptManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/27/23.
//

import AppKit
import Foundation
import os.log

class ScriptManager {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ScriptManager"
    )

    private var scriptDirectoryURL: URL?

    init() {
        promptForScriptDirectory()
    }

    func executeScript() {
        guard let directoryURL = scriptDirectoryURL else {
            logger.debug("Script directory is not set.")
            return
        }

        let scriptURL = directoryURL.appendingPathComponent("GetActiveTabURL.scpt")

        do {
            let appleScriptTask = try NSUserAppleScriptTask(url: scriptURL)
            appleScriptTask.execute(withAppleEvent: nil) { (result, error) in
                if let error = error {
                    self.logger.debug("Error: \(error)")
                } else {
                    self.logger.debug("Script executed successfully. \(result)")
                }
            }
        } catch {
            logger.debug("Failed to execute script: \(error)")
        }
    }

    func promptForScriptDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose the Application Scripts Directory"
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        if let appScriptsDir = try? FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            panel.directoryURL = appScriptsDir
        }

        let result = panel.runModal()

        if result == .OK, let selectedURL = panel.urls.first {
            writeScript(to: selectedURL)
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
}
