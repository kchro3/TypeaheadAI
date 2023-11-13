//
//  TypeaheadAIApp.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/26/23.
//

import SwiftUI
import MenuBarExtraAccess

struct SettingsScene: Scene {
    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    var body: some Scene {
        Settings {
            SettingsView(
                promptManager: appState.promptManager,
                llamaModelManager: appState.llamaModelManager,
                supabaseManager: appState.supabaseManager
            )
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

@main
struct MacOS13AndLaterAppWithOnboardingV2: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    init() {
        let context = persistenceController.container.viewContext
        _appState = StateObject(wrappedValue: AppState(context: context))
    }

    var body: some Scene {
        WindowGroup {
            OnboardingView(
//                modalManager: appState.modalManager,
//                settingsManager: appState.settingsManager,
                supabaseManager: appState.supabaseManager
            )
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(
                promptManager: appState.promptManager,
                llamaModelManager: appState.llamaModelManager,
                supabaseManager: appState.supabaseManager
            )
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            CommonMenuView(
                promptManager: appState.promptManager,
                modalManager: appState.modalManager,
                settingsManager: appState.settingsManager,
                isMenuVisible: $appState.isMenuVisible
            )
        } label: {
            Image(nsImage: NSImage(named: "MenuIcon")!.withTemplate())
        }
        .menuBarExtraAccess(isPresented: $appState.isMenuVisible)
        .menuBarExtraStyle(.window)
    }
}

struct CommonMenuView: View {
    let persistenceController = PersistenceController.shared

    @ObservedObject var promptManager: PromptManager
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var settingsManager: SettingsManager
    @Binding var isMenuVisible: Bool

    var body: some View {
        MenuView(
            promptManager: promptManager,
            modalManager: modalManager,
            settingsManager: settingsManager,
            isMenuVisible: $isMenuVisible
        )
        .environment(\.managedObjectContext, persistenceController.container.viewContext)
    }
}

extension NSImage {
    func withTemplate() -> NSImage {
        self.isTemplate = true
        return self
    }
}
