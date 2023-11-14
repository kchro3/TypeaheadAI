//
//  TypeaheadAIApp.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/26/23.
//

import SwiftUI
import MenuBarExtraAccess

@main
struct TypeaheadAIApp {
    static let onboardingKey = "hasOnboardedV4"

    static func main() {
        UserDefaults.standard.setValue(false, forKey: onboardingKey)

        if UserDefaults.standard.bool(forKey: onboardingKey) {
            MacOS13AndLaterApp.main()
        } else {
            UserDefaults.standard.setValue(true, forKey: onboardingKey)
            MacOS13AndLaterAppWithOnboardingV2.main()
        }
    }
}

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

@available(macOS 13.0, *)
struct MacOS13AndLaterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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

@available(macOS 13.0, *)
struct MacOS13AndLaterAppWithOnboardingV2: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared
    @StateObject var appState: AppState

    init() {
        let context = persistenceController.container.viewContext
        _appState = StateObject(wrappedValue: AppState(context: context))
    }

    var body: some Scene {
        Window("TypeaheadAI", id: "main") {
            OnboardingView(
                supabaseManager: appState.supabaseManager,
                modalManager: appState.modalManager,
                intentManager: appState.intentManager
            )
        }
        .windowStyle(.hiddenTitleBar)

        SettingsScene(appState: appState)

        MenuBarExtra {
            CommonMenuView(
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

struct CommonMenuView: View {
    let persistenceController = PersistenceController.shared

    @ObservedObject var promptManager: PromptManager
    @ObservedObject var modalManager: ModalManager
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var supabaseManager: SupabaseManager
    @Binding var isMenuVisible: Bool

    var body: some View {
        MenuView(
            promptManager: promptManager,
            modalManager: modalManager,
            settingsManager: settingsManager,
            supabaseManager: supabaseManager,
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
