//
//  SpecialRecordActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/15/23.
//

import AudioToolbox
import Cocoa
import Foundation
import os.log

struct RawEvent {
    let timestamp: Date
    let cgEvent: CGEvent?
    let appContext: AppContext?
}

/// Recorder actor that can listen for events and app changes and replay them
actor SpecialRecordActor: CanGetUIElements {
    private let appContextManager: AppContextManager
    private let modalManager: ModalManager

    private var isRecording = false
    private var eventMonitor: Any?
    private var appChangeObserver: Any?

    private var recordedEvents: [RawEvent] = []

    private var currentPlaybackTask: Task<Void, Error>? = nil

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
                matching: [
                    .leftMouseDown,
                    .keyDown
                ],
                handler: { event in
                    // Record the event
                    Task {
                        let appInfo = try? await self.appContextManager.getActiveAppInfo()
                        self.recordEvent(event: event, appContext: appInfo?.appContext)
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
                    let appContext = try? await self.appContextManager.getActiveAppInfo()
                    await self.handleAppChange(appContext: appContext)
                }
            }

            AudioServicesPlaySystemSoundWithCompletion(1113, {})
            self.isRecording = true
        }
    }

    private func recordEvent(event: NSEvent, appContext: AppContext?) {
        if let cgEvent = event.cgEvent {
            recordedEvents.append(RawEvent(
                timestamp: Date(),
                cgEvent: cgEvent,
                appContext: appContext
            ))
        }
    }

    private func handleAppChange(appContext: AppContext?) {
        if let appContext = appContext {
            recordedEvents.append(RawEvent(
                timestamp: Date(),
                cgEvent: nil,
                appContext: appContext
            ))
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

    /// Wrapper around playbackTask that handles cancellations
    func playback() {
        if currentPlaybackTask != nil {
            AudioServicesPlaySystemSoundWithCompletion(1114, {})
            self.logger.info("Cancelled playback")
            currentPlaybackTask?.cancel()
            currentPlaybackTask = nil
        } else {
            AudioServicesPlaySystemSoundWithCompletion(1113, {})
            self.logger.info("Start playback")
            currentPlaybackTask?.cancel()
            currentPlaybackTask = Task {
                try await self.playbackTask()
                AudioServicesPlaySystemSoundWithCompletion(1114, {})
                currentPlaybackTask = nil
            }
        }
    }

    private func playbackTask() async throws {
        // Ensure playback occurs on the main thread
        if self.isRecording {
            stopEventMonitoring()
        }

        var prevTimestamp: Date? = nil
        var prevAppContext: AppContext? = try await appContextManager.getActiveAppInfo()
        for event in self.recordedEvents {
            if let ts = prevTimestamp {
                let delta = event.timestamp.timeIntervalSince(ts)
                let nanoseconds = UInt64(delta * 1_000_000_000) // Convert seconds to nanoseconds
                try await Task.sleep(nanoseconds: nanoseconds)
            }

            if event.appContext != nil && event.appContext != prevAppContext {
                // Make sure to activate the app first
                activateApp(event.appContext)
                prevAppContext = try await appContextManager.getActiveAppInfo()
            }

            if let cgEvent = event.cgEvent {
                cgEvent.copy()?.post(tap: .cghidEventTap)
            }

            prevTimestamp = event.timestamp
        }
    }

    private func activateApp(_ appContext: AppContext?) {
        if let bundleIdentifier = appContext?.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            NSWorkspace.shared.openApplication(
                at: url,
                configuration: configuration,
                completionHandler: { (app, error) in }
            )
        }
    }
}
