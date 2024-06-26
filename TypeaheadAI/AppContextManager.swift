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

class AppContextManager: CanFetchAppContext, CanExecuteApplescript {
    private static let getActiveTabURLScript = """
    tell application "Google Chrome"
        return URL of active tab of front window
    end tell
    """

    private let appManager = AppManager()
    private let clientManager: ClientManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppContextManager"
    )

    init(clientManager: ClientManager) {
        self.clientManager = clientManager
    }

    func getActiveAppInfo() async throws -> AppInfo {
        guard var appContext = try await fetchAppContext() else {
            return AppInfo(appContext: nil, elementMap: ElementMap(), apps: appManager.getApps())
        }

        appContext.url = await getUrl(bundleIdentifier: appContext.bundleIdentifier)
        return AppInfo(appContext: appContext, elementMap: ElementMap(), apps: appManager.getApps())
    }

    private func getUrl(bundleIdentifier: String?) async -> URL? {
        if bundleIdentifier == "com.google.Chrome" {
            do {
                let urlString = try await executeScript(script: AppContextManager.getActiveTabURLScript)
                if let url = URL(string: urlString),
                   let strippedUrl = self.stripQueryParameters(from: url) {
                    return strippedUrl
                }
            } catch let error as ApiError {
                Task {
                    try? await clientManager.sendFeedback(
                        feedback: "Failed to get chrome URL: \(error.errorDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            } catch {
                Task {
                    try? await clientManager.sendFeedback(
                        feedback: "Failed to get chrome URL: \(error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
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
