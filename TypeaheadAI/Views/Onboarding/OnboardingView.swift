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
    var quickActionManager: QuickActionManager

    @AppStorage("step") var step: Int = 1
    private let totalSteps: Int = 9
    @AppStorage("hasOnboardedV4") var hasOnboarded: Bool = false

    init(
        supabaseManager: SupabaseManager,
        modalManager: ModalManager,
        intentManager: IntentManager,
        quickActionManager: QuickActionManager
    ) {
        self.supabaseManager = supabaseManager
        self.modalManager = modalManager
        self.intentManager = intentManager
        self.quickActionManager = quickActionManager
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
        } else if step == 9 {
            AnyView(AutopilotOnboardingView())
        } else {
            AnyView(OutroOnboardingView())
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
        intentManager: IntentManager(context: context, backgroundContext: context),
        quickActionManager: QuickActionManager(context: context, backgroundContext: context)
    )
}
