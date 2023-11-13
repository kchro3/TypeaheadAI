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
    var supabaseManager: SupabaseManager
    var modalManager: ModalManager

    @State private var step: Int = 0
    private let totalSteps: Int = 5

    init(supabaseManager: SupabaseManager, modalManager: ModalManager) {
        self.supabaseManager = supabaseManager
        self.modalManager = modalManager
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
                .frame(width: 400, height: 450)
            }
        }
    }

    @ViewBuilder
    var panel: some View {
        if step == 0 {
            AnyView(IntroOnboardingView())
        } else if step == 1 {
            AnyView(SmartCopyOnboardingView()
                .onReceive(NotificationCenter.default.publisher(for: .smartCopyPerformed)) { _ in
                    // Perform your UI update here
                    step += 1
                }
            )
        } else if step == 2 {
            AnyView(SmartPasteOnboardingView())
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
        modalManager: ModalManager()
    )
}
