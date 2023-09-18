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
import os.log
import MenuBarExtraAccess

@MainActor
final class AppState: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isBlinking: Bool = false
    @Published var incognitoMode: Bool = false

    private var blinkTimer: Timer?
    let logger = Logger(
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
    private var specialCutActor: SpecialCutActor? = nil
    private var specialPasteActor: SpecialPasteActor? = nil
    private var specialCopyActor: SpecialCopyActor? = nil
    private var specialSaveActor: SpecialSaveActor? = nil

    // Monitors
    private let mouseEventMonitor = MouseEventMonitor()
    // NOTE: globalEventMonitor is for debugging
    private var globalEventMonitor: Any?

    // Constants
    private let maxConcurrentRequests = 5
    private let stickyMode = true

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
        self.specialPasteActor = SpecialPasteActor(
            historyManager: historyManager,
            mouseEventMonitor: mouseEventMonitor,
            clientManager: clientManager,
            memoManager: memoManager
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
                await self.specialCopyActor?.specialCopy(incognitoMode: incognitoMode, stickyMode: stickyMode)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            self.startBlinking()
            self.mouseEventMonitor.mouseClicked = false
            Task {
                await specialPasteActor?.specialPaste(incognitoMode: incognitoMode) {
                    self.stopBlinking()
                }
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialCut) { [self] in
            Task {
                await self.specialCutActor?.specialCut(incognitoMode: incognitoMode, stickyMode: stickyMode)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialSave) { [self] in
            Task {
                await self.specialSaveActor?.specialSave(incognitoMode: incognitoMode)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatRefresh) { [self] in
            self.modalManager.forceRefresh()
        }

        KeyboardShortcuts.onKeyUp(for: .chatOpen) { [self] in
            self.modalManager.showModal(incognito: self.incognitoMode)
            NSApp.activate(ignoringOtherApps: true)
        }

        KeyboardShortcuts.onKeyUp(for: .chatNew) { [self] in
            self.modalManager.forceRefresh()
            self.modalManager.showModal(incognito: self.incognitoMode)
            NSApp.activate(ignoringOtherApps: true)
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
                modalManager: appState.modalManager,
                isMenuVisible: $isMenuVisible
            )
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .onAppear(perform: {
                appState.modalManager.showOnboardingModal()
            })
        } label: {
            Image(systemName: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard")
            // TODO: Add symbolEffect when available
        }
        .menuBarExtraAccess(isPresented: $isMenuVisible)
        .menuBarExtraStyle(.window)
    }
}
