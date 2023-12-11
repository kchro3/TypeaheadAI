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

    @ObservedObject var supabaseManager: SupabaseManager
    var modalManager: ModalManager
    var intentManager: IntentManager

    @AppStorage("step") var step: Int = 1
    private let totalSteps: Int = 8
    @AppStorage("hasOnboardedV4") var hasOnboarded: Bool = false

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
                        .id(UUID())
                        .transition(.opacity)

                    Spacer()

                    navbar
                }
                .padding(30)
                .animation(.easeInOut, value: UUID())
            } else {
                LoggedOutOnboardingView(
                    supabaseManager: supabaseManager
                )
            }
        }
        .frame(width: 500, height: 550)
    }

    @ViewBuilder
    var panel: some View {
        if step == 1 {
            AnyView(IntroOnboardingView())
        } else if step == 2 {
            AnyView(PermissionsOnboardingView())
        } else if step == 3 {
            AnyView(ActivateOnboardingView())
        } else if step == 4 {
            AnyView(SmartCopyOnboardingView()
                .onReceive(NotificationCenter.default.publisher(for: .smartCopyPerformed)) { _ in
                    self.modalManager.setUserIntents(intents: ["reply to this email"])
                    // Add a delay so that there is time to copy the text
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        step += 1
                    }
                }
            )
        } else if step == 5 {
            AnyView(
                IntentsOnboardingView()
                    .onReceive(NotificationCenter.default.publisher(for: .smartCopyPerformed)) { _ in
                        self.modalManager.setUserIntents(intents: ["reply to this email"])
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .userIntentSent)) { _ in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            step += 1
                        }
                    }
            )
        } else if step == 6 {
            AnyView(
                RefineOnboardingView()
                    .onReceive(NotificationCenter.default.publisher(for: .smartCopyPerformed)) { _ in
                        self.modalManager.setUserIntents(intents: ["reply to this email"])
                    }
            )
        } else if step == 7 {
            AnyView(SmartPasteOnboardingView())
        } else if step == 8 {
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
                        print("Mark as onboarded...")
                        hasOnboarded = true
                        window.performClose(nil)
                    }
                }

                Spacer()

                if step > 1 {
                    RoundedButton("Back") {
                        modalManager.closeModal()
                        step -= 1
                    }
                }

                if step < totalSteps {
                    RoundedButton("Continue", isAccent: true) {
                        if step != 5 && step != 6 {
                            modalManager.closeModal()
                        }
                        step += 1
                    }
                } else if step == totalSteps {
                    RoundedButton("Finish", isAccent: true) {
                        if let window = NSApplication.shared.keyWindow {
                            print("Mark as onboarded...")
                            hasOnboarded = true
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
        modalManager: ModalManager(context: context),
        intentManager: IntentManager(context: context, backgroundContext: context)
    )
}
