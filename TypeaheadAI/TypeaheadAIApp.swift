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
    @Published var isMenuVisible: Bool = false

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
    private let intentManager: IntentManager

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
        self.intentManager = IntentManager(context: context)
        self.clientManager = ClientManager()
        self.modalManager = ModalManager()
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
        self.clientManager.intentManager = intentManager
        self.modalManager.clientManager = clientManager
        self.modalManager.promptManager = promptManager

        checkAndRequestNotificationPermissions()

        KeyboardShortcuts.onKeyUp(for: .specialCopy) { [self] in
            Task {
                await self.specialCopyActor?.specialCopy(stickyMode: false)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .stickyCopy) { [self] in
            Task {
                await self.specialCopyActor?.specialCopy(stickyMode: true)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialPaste) { [self] in
            Task {
                await specialPasteActor?.specialPaste()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialCut) { [self] in
            Task {
                await self.specialCutActor?.specialCut(stickyMode: false)
            }
        }

        KeyboardShortcuts.onKeyUp(for: .specialSave) { [self] in
            Task {
                await self.specialSaveActor?.specialSave()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatOpen) { [self] in
            if let window = self.modalManager.toastWindow, !window.isVisible {
                self.modalManager.showModal()
                NSApp.activate(ignoringOtherApps: true)
            } else {
                self.modalManager.closeModal()
            }
        }

        KeyboardShortcuts.onKeyUp(for: .chatNew) { [self] in
            self.modalManager.forceRefresh()
            self.modalManager.showModal()
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
struct TypeaheadAIApp {
    static func main() {
        if #available(macOS 13.0, *) {
            if UserDefaults.standard.bool(forKey: "hasOnboardedV3") {
                MacOS13AndLaterApp.main()
            } else {
                UserDefaults.standard.setValue(true, forKey: "hasOnboardedV3")
                MacOS13AndLaterAppWithOnboardingV2.main()
            }
        } else {
            MacOS12AndEarlierApp.main()
        }
    }
}

struct SettingsScene: Scene {
    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    var body: some Scene {
        Settings {
            SettingsView(promptManager: appState.promptManager)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}

struct MacOS12AndEarlierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        SettingsScene(appState: appDelegate.appState)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarItem: NSStatusItem?
    var application: NSApplication = NSApplication.shared

    let persistenceController = PersistenceController.shared
    @ObservedObject var appState: AppState = {
        let context = PersistenceController.shared.container.viewContext
        return AppState(context: context)
    }()

    override init() {
        // Further customization if needed.
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let menuItem = NSMenuItem()

        // SwiftUI View
        let subview = CommonMenuView(
            promptManager: appState.promptManager,
            modalManager: appState.modalManager,
            isMenuVisible: $appState.isMenuVisible
        )

        let view = NSHostingView(rootView: subview)
        view.becomeFirstResponder()

        // Very important! If you don't set the frame the menu won't appear to open.
        view.frame = NSRect(x: 0, y: 0, width: 300, height: 400)
        menuItem.view = view

        menu.addItem(menuItem)

        NSApp.activate(ignoringOtherApps: true)

        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem?.button?.image = NSImage(systemSymbolName: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard", accessibilityDescription: nil)
        statusBarItem?.menu = menu
    }
}

@available(macOS 13.0, *)
struct MacOS13AndLaterApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState
    @State var text: String = ""

    init() {
        let context = persistenceController.container.viewContext
        _appState = StateObject(wrappedValue: AppState(context: context))
    }

    var body: some Scene {
        SettingsScene(appState: appState)

        MenuBarExtra {
            CommonMenuView(
                promptManager: appState.promptManager,
                modalManager: appState.modalManager,
                isMenuVisible: $appState.isMenuVisible
            )
        } label: {
            Image(systemName: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard")
            // TODO: Add symbolEffect when available
        }
        .menuBarExtraAccess(isPresented: $appState.isMenuVisible)
        .menuBarExtraStyle(.window)
    }
}

@available(macOS 13.0, *)
struct MacOS13AndLaterAppWithOnboardingV2: App {
    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    init() {
        let context = persistenceController.container.viewContext
        _appState = StateObject(wrappedValue: AppState(context: context))
    }

    var body: some Scene {
        WindowGroup {
            OnboardingView(
                modalManager: appState.modalManager
            )
        }

        SettingsScene(appState: appState)

        MenuBarExtra {
            CommonMenuView(
                promptManager: appState.promptManager,
                modalManager: appState.modalManager,
                isMenuVisible: $appState.isMenuVisible
            )
        } label: {
            Image(systemName: appState.isBlinking ? "list.clipboard.fill" : "list.clipboard")
            // TODO: Add symbolEffect when available
        }
        .menuBarExtraAccess(isPresented: $appState.isMenuVisible)
        .menuBarExtraStyle(.window)
    }
}

struct CommonMenuView: View {
    let persistenceController = PersistenceController.shared

    @ObservedObject var promptManager: PromptManager
    @ObservedObject var modalManager: ModalManager
    @Binding var isMenuVisible: Bool

    var body: some View {
        MenuView(
            promptManager: promptManager,
            modalManager: modalManager,
            isMenuVisible: $isMenuVisible
        )
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
}
