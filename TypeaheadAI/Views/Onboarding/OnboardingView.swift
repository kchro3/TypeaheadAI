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

    var clientManager: ClientManager
    var intentManager: IntentManager
    var modalManager: ModalManager
    var quickActionManager: QuickActionManager
    @ObservedObject var supabaseManager: SupabaseManager

    @AppStorage("step") var step: Int = 1

    init(
        clientManager: ClientManager,
        intentManager: IntentManager,
        modalManager: ModalManager,
        quickActionManager: QuickActionManager,
        supabaseManager: SupabaseManager
    ) {
        self.clientManager = clientManager
        self.intentManager = intentManager
        self.modalManager = modalManager
        self.quickActionManager = quickActionManager
        self.supabaseManager = supabaseManager
    }

    var body: some View {
        VStack {
            if let _ = supabaseManager.uuid {
                VStack {
                    panel
                        .id(UUID())
                        .transition(.opacity)
                        .accessibilitySortPriority(10.0)

                    Spacer()

                    OnboardingNavbarView(modalManager: modalManager)
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
            AnyView(IntroOnboardingView()
                .onAppear {
                    Task {
                        await quickActionManager.getOrCreateByLabel(
                            NSLocalizedString("Summarize content", comment: ""),
                            details: NSLocalizedString("Be concise, less than 150 words", comment: "")
                        )
                    }
                }
            )
        } else if step == 2 {
            AnyView(PermissionsOnboardingView())
        } else if step == 3 {
            AnyView(ActivateOnboardingView())
        } else if step == 4 {
            AnyView(SmartVisionOnboardingView())
        } else if step == 5 {
            AnyView(SmartFocusOnboardingView())
        } else if step == 6 {
            AnyView(AutopilotOnboardingView())
        } else {
            AnyView(OutroOnboardingView { feedback in
                try await clientManager.sendFeedback(feedback: feedback)
            })
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
        clientManager: ClientManager(),
        intentManager: IntentManager(context: context, backgroundContext: context),
        modalManager: ModalManager(context: context),
        quickActionManager: QuickActionManager(context: context, backgroundContext: context),
        supabaseManager: SupabaseManager()
    )
}
