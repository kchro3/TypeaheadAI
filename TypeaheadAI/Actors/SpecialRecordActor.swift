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

enum EventType {
    case mouseClicked
    case mouseRightClicked
    case mouseMoved
    case keyPressed
    case appChanged
}

struct RawEvent {
    let timestamp: Date
    let eventType: EventType
    let appContext: AppContext?
    let element: UIElement?
}

/// Recorder actor that can listen for events and app changes and replay them
actor SpecialRecordActor: CanFetchAppContext, CanGetUIElements {
    private let appContextManager: AppContextManager
    private let modalManager: ModalManager

    private var isRecording = false
    private var eventMonitor: Any?
    private var appChangeObserver: Any?

    private var recordedEvents: [RawEvent] = []

    private var currentPlaybackTask: Task<Void, Error>? = nil
    private let systemWideElement = AXUIElementCreateSystemWide()
    private var lastMousePosition: CGPoint? = nil
    private let mouseMoveThreshold: CGFloat = 5.0 // Set the threshold for mouse move

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

    func specialRecord() async throws {
        if isRecording {
            stopEventMonitoring()
            let appContext = try await fetchAppContext()

            let events = preprocessEvents()
            guard !events.isEmpty else {
                return
            }

            var message = "Here is a log of the recorded events:"
            for event in events {
                if let element = event.element {
                    if let serialized = element.serialize(isIndexed: false, showActions: false, maxDepth: 2) {
                        message += "\n\n - \(event.eventType) on\n\(serialized)"
                        if let appContext = event.appContext {
                            message += "\n\(appContext)"
                        }
                    }
                }
            }

            await self.modalManager.showModal()
            await self.modalManager.setUserMessage(message, isHidden: true, appContext: appContext)
            try await self.modalManager.proposeQuickAction()
        } else {
            await self.modalManager.forceRefresh()
            self.recordedEvents = []

            // Start observing mouse and keyboard events
            self.eventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [
                    .leftMouseDown,
                    .rightMouseDown,
                    .mouseMoved,
                    .keyDown,
                    .keyUp
                ],
                handler: { event in
                    // Record the event
                    Task {
                        let appContext = try await self.fetchAppContext()
                        switch event.type {
                        case .leftMouseDown:
                            let mousePos = NSEvent.mouseLocation
                            self.recordMouse(mousePos, eventType: .mouseClicked, appContext: appContext)
                        case .rightMouseDown:
                            let mousePos = NSEvent.mouseLocation
                            self.recordMouse(mousePos, eventType: .mouseRightClicked, appContext: appContext)
                        case .mouseMoved:
                            // Throttle mouse-moved events
                            let currentMousePosition = NSEvent.mouseLocation
                            if let lastPosition = self.lastMousePosition {
                                let deltaX = currentMousePosition.x - lastPosition.x
                                let deltaY = currentMousePosition.y - lastPosition.y
                                let distance = sqrt(deltaX * deltaX + deltaY * deltaY)

                                if distance > self.mouseMoveThreshold {
                                    self.lastMousePosition = currentMousePosition
                                    self.recordMouse(currentMousePosition, eventType: .mouseMoved, appContext: appContext)
                                }
                            } else {
                                self.lastMousePosition = currentMousePosition
                                self.recordMouse(currentMousePosition, eventType: .mouseMoved, appContext: appContext)
                            }
                        case .keyDown, .keyUp:
                            self.recordKey(eventType: .keyPressed, appContext: appContext)
                        default: throw NSError()
                        }
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
                    let appInfo = try? await self.appContextManager.getActiveAppInfo()
                    await self.handleAppChange(appContext: appInfo?.appContext)
                }
            }

            AudioServicesPlaySystemSoundWithCompletion(1113, {})
            self.isRecording = true
        }
    }

    private func preprocessEvents() -> [RawEvent] {
        var processedEvents: [RawEvent] = []
        for event in self.recordedEvents {
            switch event.eventType {
            case .mouseMoved:
                if let lastEvent = processedEvents.last, case .mouseMoved = lastEvent.eventType {
                    // Overwrite the last event with the latest mouse moved event
                    processedEvents[processedEvents.count - 1] = event
                } else if let lastEvent = processedEvents.last,
                          case .keyPressed = lastEvent.eventType,
                          let currElement = event.element,
                          let lastElement = lastEvent.element,
                          currElement.equals(lastElement) {
                    // Overwrite the last state of the keyPressed
                    // NOTE: This is kind of hacky, but I think it will generally work?
                    processedEvents[processedEvents.count - 1] = RawEvent(
                        timestamp: event.timestamp,
                        eventType: lastEvent.eventType,
                        appContext: event.appContext,
                        element: event.element
                    )
                } else {
                    processedEvents.append(event)
                }
            case .mouseClicked:
                guard let _ = event.element?.actions else {
                    print("nothing to click on, skipping...")
                    continue
                }

                if let lastEvent = processedEvents.last,
                   case .mouseMoved = lastEvent.eventType,
                   let currElement = event.element,
                   let lastElement = lastEvent.element {

                    if currElement.equals(lastElement) {
                        // Overwrite the last event with the latest mouse clicked event
                        processedEvents[processedEvents.count - 1] = event
                    } else {
                        // Overwrite using the element from the latest mouse moved event
                        // This is needed for cases when an element disappears on click
                        processedEvents[processedEvents.count - 1] = RawEvent(
                            timestamp: event.timestamp,
                            eventType: event.eventType,
                            appContext: event.appContext,
                            element: lastEvent.element
                        )
                    }
                } else {
                    processedEvents.append(event)
                }
            case .keyPressed:
                if let lastEvent = processedEvents.last,
                   case .keyPressed = lastEvent.eventType,
                   let currElement = event.element,
                   let lastElement = lastEvent.element {
                    if currElement.equals(lastElement) {
                        // Overwrite the last event with the latest keydown event
                        processedEvents[processedEvents.count - 1] = event
                    } else {
                        processedEvents.append(event)
                    }
                } else {
                    processedEvents.append(event)
                }
            default:
                processedEvents.append(event)
            }
        }

        return processedEvents.filter { $0.eventType != .mouseMoved }
    }

    private func handleAppChange(appContext: AppContext?) {
        if let appContext = appContext {
            recordedEvents.append(RawEvent(
                timestamp: Date(),
                eventType: .appChanged,
                appContext: appContext,
                element: nil
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

    private func recordMouse(_ mousePos: NSPoint, eventType: EventType, appContext: AppContext?) {
        if let element = systemWideElement.getMouseOverElement(mousePos)?.toUIElement() {
            self.recordedEvents.append(
                RawEvent(
                    timestamp: Date(),
                    eventType: eventType,
                    appContext: appContext,
                    element: element
                )
            )
        }
    }

    private func recordKey(eventType: EventType, appContext: AppContext?) {
        if let element = systemWideElement.getElementInFocus()?.toUIElement() {
            self.recordedEvents.append(
                RawEvent(
                    timestamp: Date(),
                    eventType: eventType,
                    appContext: appContext,
                    element: element
                )
            )
        }
    }
}
