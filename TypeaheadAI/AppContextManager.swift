//
//  AppContextManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import AppKit
import Foundation
import SwiftUI
import Vision
import os.log

typealias ElementMap = [String: AXUIElement]

/// AppContext is serializable and persistable, but the elementMap is transient.
struct AppInfo {
    var appContext: AppContext?
    var elementMap: ElementMap
    var apps: [String: Application]
}

class AppContextManager: CanFetchAppContext, CanScreenshot, CanGetUIElements {
    @AppStorage("isAutopilotEnabled") private var isAutopilotEnabled: Bool = true

    private let scriptManager = ScriptManager()
    private let appManager = AppManager()

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    func getActiveAppInfo() async throws -> AppInfo {
        guard var appContext = try await fetchAppContext() else {
            return AppInfo(appContext: nil, elementMap: ElementMap(), apps: appManager.getApps())
        }

        self.logger.info("active app: \(appContext.bundleIdentifier ?? "<unk>")")

        // NOTE: Take screenshot and store reference. We can apply the OCR when we make the network request.
        appContext.screenshotPath = try await screenshot()
        appContext.url = await getUrl(bundleIdentifier: appContext.bundleIdentifier)
        if isAutopilotEnabled {
            let (uiElement, elementMap) = getUIElements(appContext: appContext)
            if let serializedUIElement = uiElement?.serialize() {
//                print(serializedUIElement)
                appContext.serializedUIElement = serializedUIElement
            }

            return AppInfo(appContext: appContext, elementMap: elementMap, apps: appManager.getApps())
        } else {
            return AppInfo(appContext: appContext, elementMap: ElementMap(), apps: appManager.getApps())
        }
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
