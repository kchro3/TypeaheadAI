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
    let ocrText: String?
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

        var ocrText: String? = nil
        var annotatedImage: NSImage? = nil
        let screenshot = screenshotManager.takeScreenshot(activeApp: activeApp)
        if let image = screenshot {
            logger.info("took screenshot")
            (ocrText, annotatedImage) = try await screenshotManager.performOCR(image: image)  // NOTE: Figure out how we can use the annotated bounding box

            #if DEBUG
            if let nsImage = annotatedImage {
                screenshotManager.copyImageToClipboard(nsImage: nsImage)
            }
            #endif

            logger.info("OCR: \(ocrText ?? "none")")
        } else {
            logger.info("did not take screenshot")
        }

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
                        ocrText: ocrText
                    )
                }
            } catch let error {
                self.logger.error("Failed to execute script: \(error.localizedDescription)")
            }

            return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil, ocrText: ocrText)
        } else {
            return AppContext(appName: appName, bundleIdentifier: bundleIdentifier, url: nil, ocrText: ocrText)
        }
    }

    private func stripQueryParameters(from url: URL) -> URL? {
        var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        urlComponents?.query = nil
        urlComponents?.fragment = nil
        return urlComponents?.url
    }
}
