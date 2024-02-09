//
//  AppManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/11/23.
//

import Foundation

class AppManager {
    private var apps: [String: Application]

    init() {
        self.apps = AppManager.load()
    }

    func getApps() -> [String: Application] {
        return self.apps
    }

    func getApp(_ id: String) -> Application? {
        return self.apps[id]
    }
}

extension AppManager {
    static func load() -> [String: Application] {
        let fileManager = FileManager.default
        let directoriesToSearch = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true)
        ]

        var apps: [String: Application] = [:]
        for directory in directoriesToSearch {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: [.isSymbolicLinkKey]
                )

                let appURLs = contents.filter { $0.pathExtension == "app" }

                for appURL in appURLs {
                    if let bundle = Bundle(url: appURL), let bundleID = bundle.bundleIdentifier, bundleID != "ai.typeahead.TypeaheadAI" {
                        print("Application: \(appURL.lastPathComponent), Bundle ID: \(bundleID)")
                        let app = Application(bundleIdentifier: bundleID, appName: appURL.lastPathComponent, isWhitelisted: true)
                        apps[app.id] = app
                    }
                }
            } catch {
                print("Error while enumerating files \(directory.path): \(error.localizedDescription)")
            }
        }

        return apps
    }
}
