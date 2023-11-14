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

    @State private var isLoggedIn: Bool = false
    @State private var step: Int = 1
    private let totalSteps: Int = 7

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
        Group {
            if isLoggedIn {
                VStack {
                    panel

                    Spacer()

                    navbar
                }
                .padding(15)
            } else {
                LoggedOutOnboardingView(
                    supabaseManager: supabaseManager
                )
                .onReceive(NotificationCenter.default.publisher(for: .oAuthOnboardingCallback), perform: { notification in
                    guard let url = notification.userInfo?["url"] as? URL else { return }
                    Task {
                        try await supabaseManager.signinFromUrl(from: url)
                        isLoggedIn = true
                    }
                })
            }
        }
        .frame(width: 500, height: 550)
    }

    @ViewBuilder
    var panel: some View {
        if step == 1 {
            AnyView(IntroOnboardingView())
        } else if step == 2 {
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
        } else if step == 3 {
            AnyView(
                IntentsOnboardingView()
                    .onReceive(NotificationCenter.default.publisher(for: .userIntentSent)) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            step += 1
                        }
                    }
            )
        } else if step == 4 {
            AnyView(RefineOnboardingView())
        } else if step == 5 {
            AnyView(SmartPasteOnboardingView())
        } else if step == 6 {
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

                Text("Step \(step) of \(totalSteps)")

                Spacer()
            }

            HStack {
                RoundedButton("Skip") {
                    if let window = NSApplication.shared.keyWindow {
                        window.performClose(nil)
                    }
                }

                Spacer()

                if step > 1 {
                    RoundedButton("Back") {
                        Task {
                            await modalManager.closeModal()
                            step -= 1
                        }
                    }
                }

                if step < totalSteps {
                    RoundedButton("Continue", isAccent: true) {
                        Task {
                            if step != 4 {
                                await modalManager.closeModal()
                            }
                            step += 1
                        }
                    }
                } else if step == totalSteps {
                    RoundedButton("Finish", isAccent: true) {
                        if let window = NSApplication.shared.keyWindow {
                            window.performClose(nil)
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
