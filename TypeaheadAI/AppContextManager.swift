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

class AppContextManager {
    private let scriptManager = ScriptManager()
    private let screenshotManager = ScreenshotManager()

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    func getActiveAppInfo() async throws -> AppContext? {
        guard let activeApp = NSWorkspace.shared.menuBarOwningApplication else {
            return nil
        }

        let appName = activeApp.localizedName
        let bundleIdentifier = activeApp.bundleIdentifier
        self.logger.info("active app: \(bundleIdentifier ?? "<unk>")")

        // NOTE: Take screenshot and store reference. We can apply the OCR when we make the network request.
        let screenshotPath = screenshotManager.takeScreenshot(activeApp: activeApp)

        // NOTE: Get contents from Pasteboard (including Universal clipboard if phone is nearby)
        let copiedText = NSPasteboard.general.string(forType: .string)

        // TODO: Smarter to make this a trait or something.
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
                        screenshotPath: screenshotPath,
                        copiedText: copiedText
                    )
                }
            } catch {
                self.logger.error("Failed to execute script: \(error.localizedDescription)")
            }
        }

        return AppContext(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            url: nil,
            screenshotPath: screenshotPath,
            copiedText: copiedText
        )
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
