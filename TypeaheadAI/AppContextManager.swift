//
//  AppContextManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Foundation
import os.log

struct AppContext: Codable, Equatable {
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
                let result = try await self.scriptManager.executeScript()
                if let urlString = result?.stringValue,
                   let url = URL(string: urlString),
                   let strippedUrl = self.stripQueryParameters(from: url) {
                    return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: strippedUrl)
                }
            } else {
                return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil)
            }
        }

        return nil
    }

    /// DEPRECATED: Prefer the async throws implementation
    func getActiveAppInfo(completion: @escaping (AppContext?) -> Void) {
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let appName = activeApp.localizedName
            self.logger.debug("Detected active app: \(appName ?? "none")")
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                self.scriptManager.executeScript { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to execute script: \(error.errorDescription ?? "Unknown error")")
                        completion(AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil))
                    } else if let urlString = result?.stringValue,
                              let url = URL(string: urlString),
                              let strippedUrl = self.stripQueryParameters(from: url) {

                        self.logger.info("Successfully executed script. URL: \(strippedUrl.absoluteString)")
                        completion(AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: strippedUrl))
                    }
                }
            } else {
                completion(AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil))
            }
        } else {
            completion(nil)
        }
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
