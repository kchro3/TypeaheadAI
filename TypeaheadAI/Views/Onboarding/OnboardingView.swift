//
//  OnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/19/23.
//

import SwiftUI
import Supabase
import AuthenticationServices

struct OnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var supabaseManager: SupabaseManager
    var modalManager: ModalManager
    var intentManager: IntentManager

    @State private var step: Int = 0
    private let totalSteps: Int = 4

    init(
        supabaseManager: SupabaseManager,
        modalManager: ModalManager,
        intentManager: IntentManager
    ) {
        self.supabaseManager = supabaseManager
        self.modalManager = modalManager
        self.intentManager = intentManager
    }

    var body: some View {
        VStack {
            if let _ = supabaseManager.uuid {
                VStack {
                    panel

                    Spacer()

                    navbar
                }
                .padding(20)
            } else {
                LoggedOutOnboardingView(
                    supabaseManager: supabaseManager
                )
                .frame(width: 600, height: 650)
            }
        }
    }

    @ViewBuilder
    var panel: some View {
        if step == 0 {
            AnyView(IntroOnboardingView())
        } else if step == 1 {
            AnyView(SmartCopyOnboardingView()
                .onAppear(perform: {
                    /// NOTE: Seed the user intents
                    let appContext = AppContext(
                        appName: "TypeaheadAI",
                        bundleIdentifier: "ai.typeahead.TypeaheadAI",
                        url: nil
                    )
                    if self.intentManager.fetchContextualIntents(
                        limit: 1, appContext: appContext
                    ).isEmpty {
                        self.intentManager.addIntentEntry(
                            prompt: "reply to this email",
                            copiedText: "placeholder",
                            appContext: AppContext(
                                appName: "TypeaheadAI",
                                bundleIdentifier: "ai.typeahead.TypeaheadAI",
                                url: nil
                            )
                        )
                    }
                })
                .onReceive(NotificationCenter.default.publisher(for: .smartCopyPerformed)) { _ in
                    // Add a delay so that there is time to copy the text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        step += 1
                    }
                }
            )
        } else if step == 2 {
            AnyView(SmartPasteOnboardingView())
        } else if step == 3 {
            AnyView(QuickActionExplanationOnboardingView())
        } else {
            AnyView(OutroOnboardingView())
        }
    }

    @ViewBuilder
    var navbar: some View {
        VStack {
            HStack {
                Spacer()

                Text("Step \(step+1) of \(totalSteps)")

                Spacer()
            }

            HStack {
                RoundedButton("Skip") {
                    if let window = NSApplication.shared.keyWindow {
                        window.performClose(nil)
                    }
                }

                Spacer()

                if step > 0 {
                    RoundedButton("Back") {
                        Task {
                            await modalManager.closeModal()
                            step -= 1
                        }
                    }
                }

                if step + 1 < totalSteps {
                    RoundedButton("Continue", isAccent: true) {
                        Task {
                            await modalManager.closeModal()
                            step += 1
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    // Create an in-memory Core Data store
    let container = NSPersistentContainer(name: "TypeaheadAI")
    container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
    container.loadPersistentStores { _, error in
        if let error = error as NSError? {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    let context = container.viewContext
    return OnboardingView(
        supabaseManager: SupabaseManager(),
        modalManager: ModalManager(),
        intentManager: IntentManager(context: context)
    )
}
