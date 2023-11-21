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

class AppContextManager: CanFetchAppContext, CanScreenshot {
    private let scriptManager = ScriptManager()

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    func getActiveAppInfo() async throws -> AppContext? {
        guard var appContext = try await fetchAppContext() else {
            return nil
        }
        self.logger.info("active app: \(appContext.bundleIdentifier ?? "<unk>")")

        // NOTE: Take screenshot and store reference. We can apply the OCR when we make the network request.
        appContext.screenshotPath = try await screenshot()
        appContext.url = await getUrl(bundleIdentifier: appContext.bundleIdentifier)
        return appContext
    }

    private func getUrl(bundleIdentifier: String?) async -> URL? {
        if bundleIdentifier == "com.google.Chrome" {
            do {
                let result = try await self.scriptManager.executeScript(script: .getActiveTabURL)
                if let urlString = result.stringValue,
                   let url = URL(string: urlString),
                   let strippedUrl = self.stripQueryParameters(from: url) {
                    return strippedUrl
                }
            } catch {
                self.logger.error("Failed to execute script: \(error.localizedDescription)")
            }
        }

        return nil
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
