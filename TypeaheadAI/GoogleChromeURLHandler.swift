//
//  GoogleChromeURLHandler.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/27/23.
//

import Cocoa
import Foundation
import os.log

class GoogleChromeURLHandler {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "GoogleChromeURLHandler"
    )

    func getCurrentURLFromChrome() -> String? {
        return getChromeActiveURL()

        guard let chrome = SBApplication.init(bundleIdentifier: "com.google.Chrome") as GoogleChromeApplication? else {
            self.logger.error("Failed to access Google Chrome")
            return nil
        }

        // Loop through the windows to find the frontmost one
        if let windows = chrome.windows?() {
            for i in 0..<windows.count {
                if let window = windows.object(at: i) as? GoogleChromeWindow, window.index == 1 { // index 1 is frontmost
                    if let activeTab = window.activeTab {
                        if let id = activeTab.id?() {
                            self.logger.info("id: \(id)")
                        }

                        if let url = activeTab.URL {
                            self.logger.info("url: \(url)")
                            return url
                        } else {
                            self.logger.info("no url")
                        }
                    } else {
                        self.logger.info("no tab")
                    }
                    break
                }
            }
        } else {
            self.logger.info("no frontmost window")
        }

        self.logger.info("Successfully accessed Google Chrome windows")

        return nil
    }

    nonisolated private func getChromeActiveURL() -> String? {
        let source = """
            tell application "Google Chrome"
                return URL of active tab of front window
            end tell
        """

        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            if let output = script.executeAndReturnError(&error).stringValue {
                self.logger.debug("Successfully retrieved URL from Chrome: \(output)")
                return output
            } else {
                self.logger.debug("Failed to retrieve URL from Chrome: \(error)")
                return nil
            }
        }

        if let error = error {
            self.logger.debug("Error retrieving URL from Chrome: \(error)")
        }

        return nil
    }
}
