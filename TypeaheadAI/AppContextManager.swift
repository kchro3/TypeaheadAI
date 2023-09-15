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

    func getContext(completion: @escaping (AppContext) -> Void) {
        self.logger.debug("get active app")
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let appName = activeApp.localizedName
            self.logger.debug("Detected active app: \(appName ?? "none")")
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                self.scriptManager.executeScript { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to execute script: \(error.errorDescription ?? "Unknown error")")
                        completion(AppContext(
                            activeAppName: appName,
                            activeAppBundleIdentifier: bundleIdentifier,
                            url: nil
                        ))
                    } else if let url = result?.stringValue {
                        self.logger.info("Successfully executed script. URL: \(url)")
                        completion(AppContext(
                            activeAppName: appName,
                            activeAppBundleIdentifier: bundleIdentifier,
                            url: url
                        ))
                    }
                }
            } else {
                completion(AppContext(
                    activeAppName: appName,
                    activeAppBundleIdentifier: bundleIdentifier,
                    url: nil
                ))
            }
        } else {
            completion(AppContext(
                activeAppName: nil,
                activeAppBundleIdentifier: nil,
                url: nil
            ))
        }
    }
}
