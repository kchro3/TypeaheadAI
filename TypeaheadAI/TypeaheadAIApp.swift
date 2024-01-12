//
//  TypeaheadAIApp.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/26/23.
//

import Sparkle
import SwiftUI
import MenuBarExtraAccess

@main
struct TypeaheadAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let updaterController: SPUStandardUpdaterController

    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    init() {
        #if DEBUG
        // NOTE: Uncomment the following to wipe UserDefaults. Do not remove the #if DEBUG compiler flags.
//        UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
//        UserDefaults.standard.synchronize()
        #endif

        let context = persistenceController.container.viewContext
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyStoreTrumpMergePolicyType)

        let backgroundContext = persistenceController.container.newBackgroundContext()
        _appState = StateObject(wrappedValue: AppState(context: context, backgroundContext: backgroundContext))

        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(
                modalManager: appState.modalManager,
                promptManager: appState.promptManager,
                settingsManager: appState.settingsManager,
                supabaseManager: appState.supabaseManager,
                isMenuVisible: $appState.isMenuVisible,
                updater: updaterController.updater
            )
        } label: {
            Image(nsImage: NSImage(named: "MenuIcon")!.withTemplate())
                .accessibilityLabel(Text("Menu"))
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
