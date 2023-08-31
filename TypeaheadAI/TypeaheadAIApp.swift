//
//  TypeaheadAIApp.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/26/23.
//

import CoreData
import SwiftUI
import KeyboardShortcuts
import UserNotifications
import AppKit
import AVFoundation
import Carbon.HIToolbox
import os.log

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isBlinking: Bool = false
    @Published var isEnabled: Bool = true
    @Published var promptManager: PromptManager

    // Monitors: globalEventMonitor is for debugging
    private var globalEventMonitor: Any?
    private var mouseClicked: Bool = false
    private var mouseEventMonitor: Any?

    private var blinkTimer: Timer?
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppState"
    )
    private let clientManager = ClientManager()
    private let scriptManager = ScriptManager()
    private let historyManager: HistoryManager

    init(context: NSManagedObjectContext) {
        self.historyManager = HistoryManager(context: context)
        self.promptManager = PromptManager(context: context)

        checkAndRequestAccessibilityPermissions()
        checkAndRequestNotificationPermissions()

        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            self.specialCopy()
        }

        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            self.specialPaste()
        }

        startMonitoringCmdCAndV()
    }

    deinit {
        Task { // Use a task to call the method on the main actor
            await stopMonitoringCmdCAndV()
        }

        self.scriptManager.stopAccessingDirectory()
    }

    private func startBlinking() {
        // Invalidate the previous timer if it exists
        blinkTimer?.invalidate()

        // Create and schedule a new timer
        blinkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            DispatchQueue.main.async { self.isBlinking.toggle() }
        }
    }

    private func stopBlinking() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        DispatchQueue.main.async { self.isBlinking = false }
    }

    private func startMonitoringCmdCAndV() {
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyUp], handler: { event in
            DispatchQueue.main.async {
                let commandKeyUsed = event.modifierFlags.contains(.command)
                if event.keyCode == 8 && commandKeyUsed { // 'C' key
                                                          // Get the latest string content from the pasteboard
                    if let _ = NSPasteboard.general.string(forType: .string) {
                        self.logger.debug("copy detected")
                    }
                } else if event.keyCode == 9 && commandKeyUsed { // 'V' key
                    self.logger.debug("paste detected")
                }
            }
        })
    }

    private func stopMonitoringCmdCAndV() async {
        if let globalEventMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
        }
    }

    private func startMonitoringMouseClicks() {
        self.logger.debug("monitoring clicks")
        mouseClicked = false
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown], handler: { [weak self] _ in
            self?.logger.debug("click detected")
            self?.mouseClicked = true
        })
    }

    private func stopMonitoringMouseClicks() {
        if let mouseEventMonitor = mouseEventMonitor {
            self.logger.debug("stop monitoring clicks")
            NSEvent.removeMonitor(mouseEventMonitor)
            self.mouseEventMonitor = nil
        }
    }

    func specialCopy() {
        if !isEnabled {
            self.logger.debug("special copy is disabled")
            return
        }

        checkAndRequestAccessibilityPermissions()

        self.logger.debug("special copy")
        let pasteboard = NSPasteboard.general

        // Get the current items from the pasteboard
        let currentItems: [NSPasteboardItem] = pasteboard.pasteboardItems ?? []

        // Store the data for each type in a new array
        var combinedItems: [NSPasteboardItem] = []

        for item in currentItems {
            let newItem = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    newItem.setData(data, forType: type)
                }
            }
            combinedItems.append(newItem)
        }

        self.simulateCopy()

        // Append the new items to the combined items
        if let newItems = pasteboard.pasteboardItems {
            for item in newItems {
                let newItem = NSPasteboardItem()
                for type in item.types {
                    if let data = item.data(forType: type) {
                        newItem.setData(data, forType: type)
                    }
                }
                combinedItems.append(newItem)
            }
        }

        // Clear the pasteboard and write the combined items
        pasteboard.clearContents()
        pasteboard.writeObjects(combinedItems)

        // Debug print
        self.logger.debug("Number of items on pasteboard: \(combinedItems.count)")
    }

    func specialPaste() {
        if !isEnabled {
            self.logger.debug("special paste is disabled")
            return
        }

        checkAndRequestAccessibilityPermissions()

        self.logger.debug("special paste")
        let pasteboard = NSPasteboard.general
        let items = pasteboard.pasteboardItems ?? []

        if items.isEmpty {
            DispatchQueue.main.async { self.isLoading = false }
            self.logger.debug("No items found")
            return
        }

        var combinedString = ""
        for item in items {
            if let string = item.string(forType: .string) {
                if !combinedString.isEmpty {
                    combinedString += "\n" // Add newline delimiter between strings
                }
                combinedString += string
            }
        }

        if combinedString.isEmpty {
            DispatchQueue.main.async { self.isLoading = false }
            self.logger.debug("No string found")
            return
        }

        self.logger.debug("Combined string: \(combinedString)")

        let newEntry = self.historyManager.addHistoryEntry(query: combinedString)

        DispatchQueue.main.async {
            self.isLoading = true
            self.startBlinking()
            self.startMonitoringMouseClicks()
        }

        // Replace the current clipboard contents with the lowercase string
        pasteboard.declareTypes([.string], owner: nil)

        getActiveApplicationInfo { (appName, bundleIdentifier, url) in
            DispatchQueue.main.async {
                self.clientManager.sendRequest(
                    id: newEntry.id!,
                    username: NSUserName(),
                    userFullName: NSFullUserName(),
                    userObjective: self.promptManager.getActivePrompt() ?? "",
                    copiedText: combinedString,
                    url: url ?? "unknown",
                    activeAppName: appName ?? "",
                    activeAppBundleIdentifier: bundleIdentifier ?? ""
                ) { result in
                    switch result {
                    case .success(let response):
                        self.logger.debug("Response from server: \(response)")
                        self.historyManager.updateHistoryEntry(
                            entry: newEntry,
                            withResponse: response,
                            andStatus: .success
                        )
                        pasteboard.setString(response, forType: .string)
                        // Simulate a paste of the lowercase string
                        if self.mouseClicked {
                            self.sendClipboardNotification(status: .success)
                        } else {
                            AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
                            self.simulatePaste()
                        }
                    case .failure(let error):
                        self.logger.debug("Error: \(error.localizedDescription)")
                        self.historyManager.updateHistoryEntry(
                            entry: newEntry,
                            withResponse: nil,
                            andStatus: .failure
                        )
                        self.sendClipboardNotification(status: .failure)
                        AudioServicesPlaySystemSound(1306) // Funk sound
                    }

                    DispatchQueue.main.async {
                        self.isLoading = false
                        if self.historyManager.pendingRequestCount() == 0 {
                            self.stopBlinking()
                            self.stopMonitoringMouseClicks()
                        }
                    }
                }
            }
        }
    }

    private func getActiveApplicationInfo(completion: @escaping (String?, String?, String?) -> Void) {
        self.logger.debug("get active app")
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            let appName = activeApp.localizedName
            self.logger.debug("Detected active app: \(appName ?? "none")")
            let bundleIdentifier = activeApp.bundleIdentifier

            if bundleIdentifier == "com.google.Chrome" {
                self.scriptManager.executeScript { (result, error) in
                    if let error = error {
                        self.logger.error("Failed to execute script: \(error.errorDescription ?? "Unknown error")")
                        completion(appName, bundleIdentifier, nil)
                    } else if let url = result?.stringValue {
                        self.logger.info("Successfully executed script. URL: \(url)")
                        completion(appName, bundleIdentifier, url)
                    }
                }
            } else {
                completion(appName, bundleIdentifier, nil)
            }
        } else {
            completion(nil, nil, nil)
        }
    }

    private func simulateCopy() {
        self.logger.debug("simulated copy")
        // Post a Command-C keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)! // c key
        cmdCDown.flags = [.maskCommand]
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)! // c key
        cmdCUp.flags = [.maskCommand]

        cmdCDown.post(tap: .cghidEventTap)
        cmdCUp.post(tap: .cghidEventTap)
    }

    private func simulatePaste() {
        self.logger.debug("simulated paste")
        // Post a Command-V keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdVDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)! // v key
        cmdVDown.flags = [.maskCommand]
        let cmdVUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)! // v key
        cmdVUp.flags = [.maskCommand]

        cmdVDown.post(tap: .cghidEventTap)
        cmdVUp.post(tap: .cghidEventTap)
    }

    private func checkAndRequestAccessibilityPermissions() -> Void {
        // Check if the process is trusted for accessibility
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true
        ]

        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        // Debugging logs
        if accessibilityEnabled {
            self.logger.info("Accessibility permissions granted.")
        } else {
            self.logger.warning("Accessibility permissions not granted.")

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "This app requires accessibility permissions to function properly. Would you like to open System Preferences to grant these permissions?"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Preferences")
                alert.addButton(withTitle: "Cancel")

                let modalResult = alert.runModal()

                switch modalResult {
                case .alertFirstButtonReturn:
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                case .alertSecondButtonReturn:
                    // Handle cancel action if needed
                    break
                default:
                    break
                }
            }
        }
    }

    private func checkAndRequestNotificationPermissions() -> Void {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                self.logger.debug("Notification permission granted")
            } else if let error = error {
                self.logger.error("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    private func sendClipboardNotification(status: RequestStatus) {
        let content = UNMutableNotificationContent()

        if status == RequestStatus.success {
            content.title = "Clipboard Ready"
            content.body = "Paste with cmd-v."
        } else {
            content.title = "Failed to paste"
            content.body = "Something went wrong... Please try again."
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }
}

@main
struct TypeaheadAIApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appState: AppState

    init() {
        let context = persistenceController.container.viewContext
        _appState = StateObject(wrappedValue: AppState(context: context))
    }

    var body: some Scene {
        Settings {
            SettingsView(promptManager: appState.promptManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }

        MenuBarExtra {
            MenuView(isEnabled: $appState.isEnabled, promptManager: appState.promptManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        } label: {
            Image(systemName: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard")
            // TODO: Add symbolEffect when available
        }
        .menuBarExtraStyle(.window)
    }
}
