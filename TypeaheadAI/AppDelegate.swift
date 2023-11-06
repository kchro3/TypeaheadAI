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
            print("App opened with URL: \(url)")
            // You might check the path, query string, or other parts of the URL
            // to determine exactly what the app should do
//            Task {
//            }
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
        case "OPEN_TESTFLIGHT":
            if let url = URL(string: "itms-beta://") {
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
