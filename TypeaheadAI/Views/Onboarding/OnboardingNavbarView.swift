//
//  OnboardingNavbarView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/27/24.
//

import SwiftUI

struct OnboardingNavbarView: View {
    var modalManager: ModalManager

    @AppStorage("step") var step: Int = 1
    private let totalSteps: Int = 7
    @AppStorage("hasOnboardedV4") var hasOnboarded: Bool = false

    init(
        modalManager: ModalManager
    ) {
        self.modalManager = modalManager
    }

    var body: some View {
        ZStack {
            HStack {
                Spacer()

                Text("Step \(step) of \(totalSteps)")

                Spacer()
            }
            .accessibilityHidden(true)

            HStack {
                RoundedButton("Skip") {
                    if let window = NSApplication.shared.keyWindow {
                        print("Mark as onboarded...")
                        hasOnboarded = true
                        window.performClose(nil)
                    }
                }
                .accessibilityHint("Skip tutorial.")
                .accessibilitySortPriority(1.0)

                Spacer()

                if step > 1 {
                    RoundedButton("Back") {
                        modalManager.closeModal()
                        step -= 1
                    }
                    .accessibilityHint("Go back to step \(step - 1) of \(totalSteps)")
                    .accessibilitySortPriority(2.0)
                }

                if step < totalSteps {
                    RoundedButton("Continue", isAccent: true) {
                        if step != 5 && step != 6 {
                            modalManager.closeModal()
                        }
                        step += 1
                    }
                    .accessibilityHint("Continue to step \(step + 1) of \(totalSteps)")
                    .accessibilitySortPriority(3.0)

                } else if step == totalSteps {
                    RoundedButton("Finish", isAccent: true) {
                        if let window = NSApplication.shared.keyWindow {
                            print("Mark as onboarded...")
                            hasOnboarded = true
                            window.performClose(nil)
                        }
                    }
                    .accessibilitySortPriority(3.0)
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
    return OnboardingNavbarView(modalManager: ModalManager(context: context))
}
