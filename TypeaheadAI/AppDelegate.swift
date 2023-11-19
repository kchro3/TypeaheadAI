//
//  AppDelegate.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/5/23.
//

import Cocoa
import CoreGraphics
import Foundation
import Supabase
import SwiftUI
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var eventTap: CFMachPort?

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

        let eventMask = (1 << CGEventType.rightMouseDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) in
                if type == .rightMouseDown && event.flags.contains(.maskCommand) {
                    // Suppress the right-click and publish smart-click event
                    NotificationCenter.default.post(name: .smartClick, object: nil)
                    return nil
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap")
            exit(1)
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
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
