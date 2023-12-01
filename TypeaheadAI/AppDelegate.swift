//
//  AppDelegate.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/5/23.
//

import Foundation
import Supabase
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            // Handle the URL
            if url.host == "login-callback" {
                let urlDict: [String: URL] = ["url": url]
                NotificationCenter.default.post(name: .oAuthCallback, object: nil, userInfo: urlDict)
            }
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Register for push notifications
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { (granted, error) in
            if granted {
                DispatchQueue.main.async {
                    NSApplication.shared.registerForRemoteNotifications()
                }
            }
        }

        UNUserNotificationCenter.current().delegate = self
        NotificationCenter.default.post(name: .startOnboarding, object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification when the app is in the foreground
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        switch response.actionIdentifier {
        case "DOWNLOAD":
            if let urlString = response.notification.request.content.userInfo["url"] as? String,
               let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        case "DISMISS_FOREVER":
            // Logic to disable future update notifications
            UserDefaults.standard.set(false, forKey: "notifyOnUpdate")
        default:
            break
        }
        completionHandler()
    }
}
