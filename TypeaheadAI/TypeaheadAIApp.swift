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
    @Published var modalText: String = ""
    @Published var promptManager: PromptManager

    private var toastWindow: NSWindow?

    private var blinkTimer: Timer?
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppState"
    )

    // Managers
    private let clientManager = ClientManager()
    private let scriptManager = ScriptManager()
    private let historyManager: HistoryManager

    // Monitors
    private let mouseEventMonitor = MouseEventMonitor()
    // NOTE: globalEventMonitor is for debugging
    private var globalEventMonitor: Any?
    private var mouseClicked: Bool = false

    // Constants
    private let maxConcurrentRequests = 5

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

        // Configure mouse-click handler
        mouseEventMonitor.onLeftMouseDown = { [weak self] in
            self?.mouseClicked = true

            // If the toast window is open and the user clicks out,
            // we can close the window.
            if let window = self?.toastWindow {
                let mouseLocation = NSEvent.mouseLocation
                let windowRect = window.frame

                if !windowRect.contains(mouseLocation) {
                    self?.toastWindow?.close()
                    self?.clientManager.cancelStreamingTask()
                }
            }
        }

        mouseEventMonitor.startMonitoring()
    }

    deinit {
        Task {
            await stopMonitoringCmdCAndV()
            await mouseEventMonitor.stopMonitoring()
            self.scriptManager.stopAccessingDirectory()
        }
    }

    func specialCopy() {
        if !isEnabled || self.checkForTooManyRequests() {
            self.logger.debug("special copy is disabled")
            return
        }

        checkAndRequestAccessibilityPermissions()

        self.logger.debug("special copy")

        // Get the current clipboard to compare if anything changed:
        let initialCopiedText = NSPasteboard.general.string(forType: .string) ?? ""

        simulateCopy() {
            guard let copiedText = NSPasteboard.general.string(forType: .string) else {
                return
            }

            self.logger.debug("copied '\(copiedText)'")
            if copiedText == initialCopiedText && !self.modalText.isEmpty {
                // If nothing changed, then toggle the modal.
                // NOTE: An edge case is that if the modalText is empty,
                // whatever that was in the clipboard initially is from
                // a regular copy, in which case we just do the regular flow.
                if let window = self.toastWindow, window.isVisible {
                    window.close()
                } else {
                    self.showSpecialCopyModal()
                }
            } else {
                // Clear the modal text and reissue request
                self.modalText = ""
                self.showSpecialCopyModal()
                self.getActiveApplicationInfo { (appName, bundleIdentifier, url) in
                    Task {
                        await self.clientManager.sendStreamRequest(
                            id: UUID(),
                            username: NSUserName(),
                            userFullName: NSFullUserName(),
                            userObjective: self.promptManager.getActivePrompt() ?? "",
                            copiedText: copiedText,
                            url: url ?? "unknown",
                            activeAppName: appName ?? "",
                            activeAppBundleIdentifier: bundleIdentifier ?? ""
                        ) { (chunk, error) in
                            if let chunk = chunk {
                                DispatchQueue.main.async {
                                    self.modalText += chunk
                                }
                                self.logger.info("Received chunk: \(chunk)")
                            }
                            if let error = error {
                                self.logger.error("An error occurred: \(error)")
                            }
                        }
                    }
                }
            }
        }
    }

    func specialPaste() {
        if !isEnabled || self.checkForTooManyRequests() {
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
            self.mouseClicked = false
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
                        pasteboard.setString(response, forType: .string)
                        // Simulate a paste of the lowercase string
                        if self.mouseClicked || newEntry.id != self.historyManager.mostRecentPending() {
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
            }
        }
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

    private func simulateCopy(completion: @escaping () -> Void) {
        self.logger.debug("simulated copy")
        // Post a Command-C keystroke
        let source = CGEventSource(stateID: .hidSystemState)!
        let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)! // c key
        cmdCDown.flags = [.maskCommand]
        let cmdCUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)! // c key
        cmdCUp.flags = [.maskCommand]

        cmdCDown.post(tap: .cghidEventTap)
        cmdCUp.post(tap: .cghidEventTap)

        // Delay for the clipboard to update, then call the completion handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion()
        }
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

    private func showSpecialCopyModal() {
        toastWindow?.close()

        let contentView = ModalView(showModal: .constant(true), appState: self)

        // Create the visual effect view with frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .popover

        // Create the window
        toastWindow = CustomModalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [.closable, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )

        // Create the hosting view for SwiftUI and add it to the visual effect view
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffect.addSubview(hostingView)

        // Add constraints to make the hosting view fill the visual effect view
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor)
        ])

        // Set the visual effect view as the window's content view
        toastWindow?.contentView = visualEffect

        // Set the x, y coordinates to the user's last preference or the center by default
        if let x = UserDefaults.standard.value(forKey: "toastWindowX") as? CGFloat,
           let y = UserDefaults.standard.value(forKey: "toastWindowY") as? CGFloat {
            toastWindow?.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            toastWindow?.center()
        }

        toastWindow?.titlebarAppearsTransparent = true
        toastWindow?.isMovableByWindowBackground = true
        toastWindow?.isReleasedWhenClosed = false
        toastWindow?.level = .popUpMenu
        toastWindow?.makeKeyAndOrderFront(nil)

        // Register for window moved notifications to save the new position
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification, object: toastWindow)
    }

    @objc func windowDidMove(_ notification: Notification) {
        if let movedWindow = notification.object as? NSWindow {
            let origin = movedWindow.frame.origin
            UserDefaults.standard.set(origin.x, forKey: "toastWindowX")
            UserDefaults.standard.set(origin.y, forKey: "toastWindowY")
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
        WindowGroup {
            SplashView()
        }

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
