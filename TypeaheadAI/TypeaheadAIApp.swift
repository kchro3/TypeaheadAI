//
//  TypeaheadAIApp.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/26/23.
//

import SwiftUI
import MenuBarExtraAccess

@main
struct TypeaheadAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    init() {
        #if DEBUG
//        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
//        UserDefaults.standard.synchronize()
        #endif

        let context = persistenceController.container.viewContext
        let backgroundContext = persistenceController.container.newBackgroundContext()
        _appState = StateObject(wrappedValue: AppState(context: context, backgroundContext: backgroundContext))
    }

    var body: some Scene {
        Settings {
            SettingsView(
                promptManager: appState.promptManager,
                llamaModelManager: appState.llamaModelManager,
                supabaseManager: appState.supabaseManager
            )
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuView(
                promptManager: appState.promptManager,
                modalManager: appState.modalManager,
                settingsManager: appState.settingsManager,
                supabaseManager: appState.supabaseManager,
                isMenuVisible: $appState.isMenuVisible
            )
        } label: {
            Image(nsImage: NSImage(named: "MenuIcon")!.withTemplate())
        }
        .menuBarExtraAccess(isPresented: $appState.isMenuVisible)
        .menuBarExtraStyle(.window)
    }
}

extension NSImage {
    func withTemplate() -> NSImage {
        self.isTemplate = true
        return self
    }
}
