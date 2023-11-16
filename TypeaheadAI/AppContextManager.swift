//
//  AppContextManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Foundation
import Vision
import os.log

struct AppContext: Codable {
    let appName: String?
    let bundleIdentifier: String?
    let url: URL?
    var screenshotPath: String? = nil
    var ocrText: String? = nil
}

class AppContextManager {
    private let scriptManager = ScriptManager()
    private let screenshotManager = ScreenshotManager()

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    func getActiveAppInfo() async throws -> AppContext? {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appName = activeApp.localizedName
        let bundleIdentifier = activeApp.bundleIdentifier
        self.logger.info("active app: \(bundleIdentifier ?? "<unk>")")

        // NOTE: Take screenshot and store reference. We can apply the OCR when we make the network request.
        let screenshotPath = screenshotManager.takeScreenshot(activeApp: activeApp)

        if bundleIdentifier == "com.google.Chrome" {
            do {
                let result = try await self.scriptManager.executeScript(script: .getActiveTabURL)
                if let urlString = result.stringValue,
                   let url = URL(string: urlString),
                   let strippedUrl = self.stripQueryParameters(from: url) {
                    return AppContext(
                        appName: appName,
                        bundleIdentifier: bundleIdentifier,
                        url: strippedUrl,
                        screenshotPath: screenshotPath
                    )
                }
            } catch {
                self.logger.error("Failed to execute script: \(error.localizedDescription)")
            }

            return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil)
        } else {
            return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil)
        }
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
