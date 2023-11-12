//
//  SpecialRecordActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/8/23.
//

import AudioToolbox
import Cocoa
import Foundation
import os.log

extension Notification.Name {
    static let appDidChange = Notification.Name("NSWorkspaceDidActivateApplicationNotification")
}

struct UserEvent {
    let timestamp: Date
    let cgEvent: CGEvent?
    let appChangeEvent: AppContext?  // Maybe we always want to get the current app context
}

/// Recorder actor that can listen for events and app changes and replay them
actor SpecialRecordActor: CanSimulateScreengrab, CanPerformOCR {
    private let appContextManager: AppContextManager
    private let modalManager: ModalManager

    private var isRecording = false
    private var eventMonitor: Any?
    private var appChangeObserver: Any?

    private var recordedEvents: [UserEvent] = []

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialRecordActor"
    )

    init(
        appContextManager: AppContextManager,
        modalManager: ModalManager
    ) {
        self.appContextManager = appContextManager
        self.modalManager = modalManager
    }

    func specialRecord() async {
        if isRecording {
            stopEventMonitoring()
        } else {
            self.recordedEvents = []

            // Start observing mouse and keyboard events
            self.eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.any],
                handler: { event in
                    // Record the event
                    Task {
                        let appContext = try? await self.appContextManager.getActiveAppInfoAsync()
                        self.recordEvent(event: event, appContext: appContext)
                    }
                }
            )

            // Start observing app changes
            self.appChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: OperationQueue.main
            ) { notification in
                Task {
                    let appContext = try? await self.appContextManager.getActiveAppInfoAsync()
                    await self.handleAppChange(appContext: appContext)
                }
            }

            AudioServicesPlaySystemSoundWithCompletion(1113, {})
            self.isRecording = true
        }
    }

    private func recordEvent(event: NSEvent, appContext: AppContext?) {
        if let cgEvent = event.cgEvent {
            recordedEvents.append(UserEvent(
                timestamp: Date(),
                cgEvent: cgEvent,
                appChangeEvent: appContext
            ))
        }
    }

    private func handleAppChange(appContext: AppContext?) {
        if let appContext = appContext {
            recordedEvents.append(UserEvent(
                timestamp: Date(),
                cgEvent: nil,
                appChangeEvent: appContext
            ))
        }
    }

    private func startAppChangeMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: .appDidChange,
            object: nil,
            queue: nil
        ) { notification in
            if let userInfo = notification.userInfo,
               let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                // Handle the active app change
                self.logger.log("Application changed to: \(app.localizedName ?? "unknown")")
            }
        }
    }

    /// Tear down monitors
    private func stopEventMonitoring() {
        AudioServicesPlaySystemSoundWithCompletion(1114, {})
        isRecording = false

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }

        if let observer = appChangeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appChangeObserver = nil
        }
    }
    
    func playback() {
        // Ensure playback occurs on the main thread
        if self.isRecording {
            stopEventMonitoring()
        }

        var prevTimestamp: Date? = nil
        for event in self.recordedEvents {
            if let ts = prevTimestamp {
                Thread.sleep(forTimeInterval: event.timestamp.timeIntervalSince(ts))
            }

            if let cgEvent = event.cgEvent {
                cgEvent.copy()?.post(tap: .cghidEventTap)
            } else if let bundleIdentifier = event.appChangeEvent?.bundleIdentifier,
                      let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true

                NSWorkspace.shared.openApplication(
                    at: url,
                    configuration: configuration,
                    completionHandler: { (app, error) in }
                )
            }

            prevTimestamp = event.timestamp
        }
    }
}
