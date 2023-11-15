//
//  AppState.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/5/23.
//

import AudioToolbox
import Foundation
import KeyboardShortcuts
import os.log
import SwiftUI
import UserNotifications

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isBlinking: Bool = false
    @Published var isMenuVisible: Bool = false

    private var updateTimer: Timer?
    let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "AppState"
    )

    // Managers
    @Published var promptManager: PromptManager
    @Published var llamaModelManager = LlamaModelManager()
    @Published var modalManager: ModalManager
    @Published var settingsManager: SettingsManager
    @Published var onboardingWindowManager: OnboardingWindowManager
    @Published var clientManager: ClientManager
    @Published var intentManager: IntentManager

    var supabaseManager = SupabaseManager()

    private let historyManager: HistoryManager
    private let appContextManager: AppContextManager
    private let memoManager: MemoManager

    // Actors
    private var specialCutActor: SpecialCutActor? = nil
    private var specialPasteActor: SpecialPasteActor? = nil
    private var specialCopyActor: SpecialCopyActor? = nil
    private var specialSaveActor: SpecialSaveActor? = nil
    private var specialOpenActor: SpecialOpenActor? = nil

    // Monitors
    private let mouseEventMonitor = MouseEventMonitor()
    // NOTE: globalEventMonitor is for debugging
    private var globalEventMonitor: Any?

    // Constants
    private let maxConcurrentRequests = 5
    private let stickyMode = true

    private var appVersion: AppVersion? = nil
    // This represents the latest app version that the user has acknowledged
    private var latestAppVersion: AppVersion? = nil

    @AppStorage("notifyOnUpdate") private var notifyOnUpdate: Bool = true

    init(context: NSManagedObjectContext) {

        // Initialize managers
        self.memoManager = MemoManager(context: context)
        self.historyManager = HistoryManager(context: context)
        self.promptManager = PromptManager(context: context)
        self.intentManager = IntentManager(context: context)
        self.clientManager = ClientManager()
        self.modalManager = ModalManager()
        self.settingsManager = SettingsManager(context: context)
        self.onboardingWindowManager = OnboardingWindowManager(context: context)
        self.appContextManager = AppContextManager()

        // Initialize actors
        self.specialCopyActor = SpecialCopyActor(
            historyManager: historyManager,
            clientManager: clientManager,
            promptManager: promptManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )
        self.specialPasteActor = SpecialPasteActor(
            historyManager: historyManager,
            promptManager: promptManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )
        self.specialCutActor = SpecialCutActor(
            mouseEventMonitor: mouseEventMonitor,
            promptManager: promptManager,
            clientManager: clientManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )
        self.specialSaveActor = SpecialSaveActor(
            modalManager: modalManager,
            clientManager: clientManager,
            memoManager: memoManager
        )
        self.specialOpenActor = SpecialOpenActor(
            clientManager: clientManager,
            modalManager: modalManager,
            appContextManager: appContextManager
        )

        // Set lazy params
        // TODO: Use a dependency injection framework or encapsulate these managers
        self.clientManager.llamaModelManager = llamaModelManager
        self.clientManager.promptManager = promptManager
        self.clientManager.appContextManager = appContextManager
        self.clientManager.intentManager = intentManager
        self.clientManager.historyManager = historyManager
        self.clientManager.supabaseManager = supabaseManager

        self.modalManager.clientManager = clientManager
        self.modalManager.promptManager = promptManager
        self.modalManager.settingsManager = settingsManager

        self.settingsManager.llamaModelManager = llamaModelManager
        self.settingsManager.promptManager = promptManager
        self.settingsManager.supabaseManager = supabaseManager

        self.onboardingWindowManager.supabaseManager = supabaseManager
        self.onboardingWindowManager.modalManager = modalManager
        self.onboardingWindowManager.intentManager = intentManager

        checkAndRequestNotificationPermissions()

        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            Task {
                do {
                    try await self.specialCopyActor?.specialCopy(stickyMode: false)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .smartCopyPerformed, object: nil)
                    }
                } catch {
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .stickyCopy) { [self] in
            Task {
                try await self.specialCopyActor?.specialCopy(stickyMode: true)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            Task {
                do {
                    try await specialPasteActor?.specialPaste()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .smartPastePerformed, object: nil)
                    }
                } catch {
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialCut) { [self] in
            Task {
                try await self.specialCutActor?.specialCut(stickyMode: false)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialSave) { [self] in
            Task {
                await self.specialSaveActor?.specialSave()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatOpen) { [self] in
            Task {
                try await self.specialOpenActor?.specialOpen()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatNew) { [self] in
            Task {
                try await self.specialOpenActor?.specialOpen(forceRefresh: true)
            }
        }

        // Configure mouse-click handler
        mouseEventMonitor.onLeftMouseDown = { [weak self] in
            self?.mouseEventMonitor.mouseClicked = true

            // If the toast window is open and the user clicks out,
            // we can close the window.
            // NOTE: If the user has chatted, then keep it open.
            if let window = self?.modalManager.toastWindow,
               (self?.modalManager.messages.count ?? 0) < 2 {
                let mouseLocation = NSEvent.mouseLocation
                let windowRect = window.frame

                if !windowRect.contains(mouseLocation) {
                    self?.modalManager.closeModal()
                }
            }
        }

        mouseEventMonitor.startMonitoring()

        appVersion = getAppVersion()
        startCheckingForUpdates()
    }

    deinit {
        mouseEventMonitor.stopMonitoring()
        Task {
            await stopCheckingForUpdates()
        }
    }

    private func getAppVersion() -> AppVersion? {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            self.logger.error("Could not access app version")
            return nil
        }

        let versionComponents = version.components(separatedBy: ".")
        guard versionComponents.count == 2,
              let majorVersion = Int(versionComponents[0]),
              let minorVersion = Int(versionComponents[1]),
              let buildVersion = Int(build) else {
            self.logger.error("Could not parse app version")
            return nil
        }

        return AppVersion(major: majorVersion, minor: minorVersion, build: buildVersion)
    }

    private func startCheckingForUpdates() {
        // Invalidate the previous timer if it exists
        updateTimer?.invalidate()

        // Create and schedule a new timer every hour
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                if await !self.notifyOnUpdate {
                    return
                }

                guard let version = await self.clientManager.checkUpdates() else {
                    return
                }

                guard let appVersion = await self.appVersion else {
                    return
                }

                // NOTE: Check if current app is at least as new as the latest published version
                if await self.isLatestVersion(a: appVersion, b: version) {
                    return
                }

                if let latestVersion = await self.latestAppVersion,
                   await self.isLatestVersion(a: latestVersion, b: version) {
                    return
                }

                // NOTE: This means that it's the first time we have seen this version.
                self.logger.debug("Detected new app version")
                DispatchQueue.main.async {
                    self.latestAppVersion = version
                    self.sendNotification()
                }
            }
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "New Version Available"
        content.body = "A new version of the app is available. Tap to see options."
        content.sound = UNNotificationSound.default

        // Define the actions
        let openAction = UNNotificationAction(identifier: "OPEN_TESTFLIGHT", title: "Open TestFlight", options: .foreground)
        let dismissAction = UNNotificationAction(identifier: "DISMISS_FOREVER", title: "Ignore updates from now on", options: .destructive)
        let categoryIdentifier = "NEW_VERSION_CATEGORY"
        let category = UNNotificationCategory(identifier: categoryIdentifier, actions: [openAction, dismissAction], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        content.categoryIdentifier = categoryIdentifier

        let request = UNNotificationRequest(identifier: "NewVersionNotification", content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.debug("Failed to send notification: \(error.localizedDescription)")
            } else {
                self.logger.debug("Notification sent successfully")
            }
        }
    }

    /// Return true if newer or same version
    private func isLatestVersion(a: AppVersion, b: AppVersion) -> Bool {
        if a.major != b.major {
            return a.major > b.major
        }

        if a.minor != b.minor {
            return a.minor > b.minor
        }

        return a.build >= b.build
    }

    private func stopCheckingForUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
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
}
