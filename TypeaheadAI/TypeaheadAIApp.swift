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
import MenuBarExtraAccess

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isBlinking: Bool = false
    @Published var incognitoMode: Bool = false

    private var blinkTimer: Timer?
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppState"
    )

    // Managers
    @Published var promptManager: PromptManager
    @Published var llamaModelManager = LlamaModelManager()
    @Published var modalManager: ModalManager
    @Published var clientManager: ClientManager
    private let historyManager: HistoryManager
    private let appContextManager: AppContextManager
    private let memoManager: MemoManager

    // Actors
    // TODO: See if paste can fit actor model
    private var specialCutActor: SpecialCutActor? = nil
    private var specialCopyActor: SpecialCopyActor? = nil
    private var specialSaveActor: SpecialSaveActor? = nil

    // Monitors
    private let mouseEventMonitor = MouseEventMonitor()
    // NOTE: globalEventMonitor is for debugging
    private var globalEventMonitor: Any?

    // Constants
    private let maxConcurrentRequests = 5

    init(context: NSManagedObjectContext) {

        // Initialize managers
        self.memoManager = MemoManager(context: context)
        self.historyManager = HistoryManager(context: context)
        self.promptManager = PromptManager(context: context)
        self.clientManager = ClientManager()
        self.modalManager = ModalManager()
        self.appContextManager = AppContextManager()

        // Initialize actors
        self.specialCopyActor = SpecialCopyActor(
            clientManager: clientManager,
            modalManager: modalManager
        )
        self.specialCutActor = SpecialCutActor(
            mouseEventMonitor: mouseEventMonitor,
            clientManager: clientManager,
            modalManager: modalManager
        )
        self.specialSaveActor = SpecialSaveActor(
            modalManager: modalManager,
            clientManager: clientManager,
            memoManager: memoManager
        )

        // Set lazy params
        // TODO: Use a dependency injection framework or encapsulate these managers
        self.clientManager.llamaModelManager = llamaModelManager
        self.clientManager.promptManager = promptManager
        self.clientManager.appContextManager = appContextManager
        self.modalManager.clientManager = clientManager

        checkAndRequestNotificationPermissions()

        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            Task {
                await self.specialCopyActor?.specialCopy(incognitoMode: incognitoMode)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            self.specialPaste()
        }

        KeyboardShortcuts.onKeyUp(for: .specialCut) { [self] in
            Task {
                await self.specialCutActor?.specialCut(incognitoMode: incognitoMode)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialSave) { [self] in
            Task {
                await self.specialSaveActor?.specialSave(incognitoMode: incognitoMode)
            }
        }

        // Configure mouse-click handler
        mouseEventMonitor.onLeftMouseDown = { [weak self] in
            // If the toast window is open and the user clicks out,
            // we can close the window.
            // NOTE: If the user has chatted, then keep it open.
            if let window = self?.modalManager.toastWindow,
               (self?.modalManager.messages.count ?? 0) < 2 {
                let mouseLocation = NSEvent.mouseLocation
                let windowRect = window.frame

                if !windowRect.contains(mouseLocation) {
                    self?.modalManager.toastWindow?.close()
                    self?.clientManager.cancelStreamingTask()
                }
            }
        }

        mouseEventMonitor.startMonitoring()
    }

    deinit {
        Task {
            await mouseEventMonitor.stopMonitoring()
        }
    }

    func specialPaste() {
        if self.checkForTooManyRequests() {
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
            self.mouseEventMonitor.mouseClicked = false
        }

        // Replace the current clipboard contents with the lowercase string
        pasteboard.declareTypes([.string], owner: nil)

        self.clientManager.predict(
            id: newEntry.id!,
            copiedText: combinedString,
            incognitoMode: self.incognitoMode,
            streamHandler: { _ in },
            completion: { result in
                switch result {
                case .success(let response):
                    self.logger.debug("Response from server: \(response)")
                    pasteboard.setString(response, forType: .string)
                    // Simulate a paste of the lowercase string
                    if self.mouseEventMonitor.mouseClicked || newEntry.id != self.historyManager.mostRecentPending() {
                        self.sendClipboardNotification(status: .success)
                    } else {
                        AudioServicesPlaySystemSound(kSystemSoundID_UserPreferredAlert)
                        self.simulatePaste()
                    }
                    self.historyManager.updateHistoryEntry(
                        entry: newEntry,
                        withResponse: response,
                        andStatus: .success
                    )
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
                    }
                }
            }
        )
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
        content.sound = UNNotificationSound.default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    private func checkForTooManyRequests() -> Bool {
        if self.historyManager.pendingRequestCount() >= maxConcurrentRequests {
            sendTooManyRequestsNotification()
            return true
        } else {
            return false
        }
    }

    private func sendTooManyRequestsNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Too many requests"
        content.body = "Too many requests at a time. Please try again later."
        content.sound = UNNotificationSound.default

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
    @State var isMenuVisible: Bool = false

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
            MenuView(
                incognitoMode: $appState.incognitoMode,
                promptManager: appState.promptManager,
                isMenuVisible: $isMenuVisible
            )
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        } label: {
            Image(systemName: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard")
            // TODO: Add symbolEffect when available
        }
        .menuBarExtraAccess(isPresented: $isMenuVisible)
        .menuBarExtraStyle(.window)
    }
}
