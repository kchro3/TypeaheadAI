//
//  VersionManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/30/23.
//

import Foundation
import SwiftUI
import UserNotifications

class VersionManager {
    var clientManager: ClientManager?

    private let currentVersion: AppVersion?
    private var updateTimer: Timer?

    // This represents the latest app version that the user has acknowledged
    private var latestAckedAppVersion: AppVersion? = nil

    @AppStorage("notifyOnUpdate") private var notifyOnUpdate: Bool = true

    init() {
        currentVersion = VersionManager.getCurrentVersion()
        startCheckingForUpdates()
    }

    deinit {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func startCheckingForUpdates() {
        // Invalidate the previous timer if it exists
        updateTimer?.invalidate()

        // Create and schedule a new timer every hour
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                try await self.checkForUpdates()
            }
        }
    }

    func checkForUpdates(adhoc: Bool = false) async throws {
        if !adhoc, !self.notifyOnUpdate {
            return
        }

        guard let latest = await self.clientManager?.getLatestVersion(),
              let current = self.currentVersion else {
            return
        }

        // Check if current app is at least as new as the latest published version
        if self.isLatestVersion(current: current, latest: latest) {
            if adhoc {
                try await sendNoOpNotification()
            }
            return
        }

        if !adhoc,
           let latestVersion = self.latestAckedAppVersion,
           self.isLatestVersion(current: latestVersion, latest: latest) {
            // If the user has already acknowledged that this version exists, don't notify
            return
        }

        // Update the latest acknowledged version and send a notification
        self.latestAckedAppVersion = latest
        try await self.sendNotification(latest: latest)
    }

    private func sendNotification(latest: AppVersion) async throws {
        let content = UNMutableNotificationContent()
        content.title = "New Version Available"
        content.body = "A new version of the app is available. Tap to see options."
        content.sound = UNNotificationSound.default

        // Define the actions
        let downloadAction = UNNotificationAction(identifier: "DOWNLOAD", title: "Download latest version", options: .foreground)
        let dismissAction = UNNotificationAction(identifier: "DISMISS_FOREVER", title: "Ignore updates from now on", options: .destructive)
        let categoryIdentifier = "NEW_VERSION_CATEGORY"
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [downloadAction, dismissAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "url": latest.url ?? "https://typeahead.ai"
        ]

        let request = UNNotificationRequest(identifier: "NewVersionNotification", content: content, trigger: nil)

        try await UNUserNotificationCenter.current().add(request)
    }

    private func sendNoOpNotification() async throws {
        let content = UNMutableNotificationContent()
        content.title = "Typeahead is up-to-date"
        content.body = "You are on the latest available version."
        content.sound = UNNotificationSound.default
        let request = UNNotificationRequest(identifier: "LatestVersionNotification", content: content, trigger: nil)
        try await UNUserNotificationCenter.current().add(request)
    }
}

extension VersionManager {
    /// Return true if newer or same version
    private func isLatestVersion(current: AppVersion, latest: AppVersion) -> Bool {
        guard current != latest else {
            return true
        }

        if current.major != latest.major {
            return current.major > latest.major
        }

        if current.minor != latest.minor {
            return current.minor > latest.minor
        }

        return current.patch >= latest.patch
    }

    private static func getCurrentVersion() -> AppVersion? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return nil
        }

        let versionComponents = version.components(separatedBy: ".")
        guard versionComponents.count == 3,
              let majorVersion = Int(versionComponents[0]),
              let minorVersion = Int(versionComponents[1]),
              let patch = Int(versionComponents[2]) else {
            return nil
        }

        return AppVersion(major: majorVersion, minor: minorVersion, patch: patch, url: nil)
    }
}
