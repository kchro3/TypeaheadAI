//
//  AppContextManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Foundation
import os.log

class AppContextManager {
    private let scriptManager: ScriptManager = ScriptManager()

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    func getActiveAppInfo(completion: @escaping (String?, String?, String?) -> Void) {
        self.logger.debug("get active app")
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let appName = activeApp.localizedName
            self.logger.debug("Detected active app: \(appName ?? "none")")
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                self.scriptManager.executeScript { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to execute script: \(error.errorDescription ?? "Unknown error")")
                        completion(appName, bundleIdentifier, nil)
                    } else if let urlString = result?.stringValue,
                              let url = URL(string: urlString),
                              let strippedUrl = self.stripQueryParameters(from: url)?.absoluteString {

                        self.logger.info("Successfully executed script. URL: \(strippedUrl)")
                        completion(appName, bundleIdentifier, strippedUrl)
                    }
                }
            } else {
                completion(appName, bundleIdentifier, nil)
            }
        } else {
            completion(nil, nil, nil)
        }
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
