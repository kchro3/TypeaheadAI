//
//  AppContextManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Foundation
import os.log

struct AppContext: Codable {
    let appName: String?
    let bundleIdentifier: String?
    let url: URL?
}

class AppContextManager {
    private let scriptManager: ScriptManager = ScriptManager()

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    func getActiveAppInfo() async throws -> AppContext? {
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let appName = activeApp.localizedName
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                do {
                    let result = try await self.scriptManager.executeScript()
                    if let urlString = result.stringValue,
                       let url = URL(string: urlString),
                       let strippedUrl = self.stripQueryParameters(from: url) {
                        return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: strippedUrl)
                    }
                } catch let error {
                    self.logger.error("Failed to execute script: \(error.localizedDescription)")
                }

                return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil)
            } else {
                return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil)
            }
        } else {
            return nil
        }
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
