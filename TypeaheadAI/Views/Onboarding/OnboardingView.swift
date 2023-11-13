//
//  OnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/19/23.
//

import SwiftUI
import Supabase
import AuthenticationServices

struct LoggedInOnboardingView: View {
    init() {
        print("init")
    }

    var body: some View {
        Text("Signed in")
    }
}

struct OnboardingView: View {
    var supabaseManager: SupabaseManager

    init(supabaseManager: SupabaseManager) {
        print("init onboarding")
        self.supabaseManager = supabaseManager
    }

    var body: some View {
        VStack {
            if let _ = supabaseManager.uuid {
                LoggedInOnboardingView()
            } else {
                LoggedOutOnboardingView(supabaseManager: supabaseManager)
                    .frame(width: 400, height: 450)
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
    return OnboardingView(supabaseManager: SupabaseManager())
}
