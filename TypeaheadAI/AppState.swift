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
    @Published var promptManager: QuickActionManager
    @Published var llamaModelManager = LlamaModelManager()
    @Published var modalManager: ModalManager
    @Published var settingsManager: SettingsManager
    @Published var onboardingWindowManager: OnboardingWindowManager
    @Published var clientManager: ClientManager
    @Published var intentManager: IntentManager

    var supabaseManager = SupabaseManager()
    var versionManager = VersionManager()

    private let historyManager: HistoryManager
    private let appContextManager: AppContextManager

    // Actors
    private var specialCutActor: SpecialCutActor? = nil
    private var specialPasteActor: SpecialPasteActor? = nil
    private var specialCopyActor: SpecialCopyActor? = nil
    private var specialOpenActor: SpecialOpenActor? = nil

    // Monitors
    private let mouseEventMonitor = MouseEventMonitor()
    // NOTE: globalEventMonitor is for debugging
    private var globalEventMonitor: Any?

    init(context: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {

        // Initialize managers
        self.historyManager = HistoryManager(context: context, backgroundContext: backgroundContext)
        self.promptManager = QuickActionManager(context: context, backgroundContext: backgroundContext)
        self.intentManager = IntentManager(context: context, backgroundContext: backgroundContext)
        self.clientManager = ClientManager()
        self.modalManager = ModalManager()
        self.settingsManager = SettingsManager(context: context)
        self.onboardingWindowManager = OnboardingWindowManager(context: context)
        self.appContextManager = AppContextManager()

        // Initialize actors
        self.specialCopyActor = SpecialCopyActor(
            intentManager: intentManager,
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
        self.specialOpenActor = SpecialOpenActor(
            intentManager: intentManager,
            clientManager: clientManager,
            promptManager: promptManager,
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

        self.settingsManager.clientManager = clientManager
        self.settingsManager.llamaModelManager = llamaModelManager
        self.settingsManager.promptManager = promptManager
        self.settingsManager.supabaseManager = supabaseManager

        self.onboardingWindowManager.supabaseManager = supabaseManager
        self.onboardingWindowManager.modalManager = modalManager
        self.onboardingWindowManager.intentManager = intentManager

        self.versionManager.clientManager = clientManager

        checkAndRequestNotificationPermissions()

        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            Task {
                do {
                    try await self.specialCopyActor?.specialCopy()
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .smartCopyPerformed, object: nil)
                    }
                } catch {
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
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
                do {
                    try await self.specialCutActor?.specialCut()
                } catch {
                    self.logger.error("\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatOpen) { [self] in
            Task {
                do {
                    try await self.specialOpenActor?.specialOpen()
                } catch {
                    self.logger.error("\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatNew) { [self] in
            Task {
                do {
                    try await self.specialOpenActor?.specialOpen(forceRefresh: true)
                } catch {
                    self.logger.error("\(error.localizedDescription)")
                    AudioServicesPlaySystemSoundWithCompletion(1103, nil)
                }
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
    }

    deinit {
        mouseEventMonitor.stopMonitoring()
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
