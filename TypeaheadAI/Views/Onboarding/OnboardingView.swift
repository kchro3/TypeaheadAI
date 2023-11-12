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
    @EnvironmentObject var supabaseManager: SupabaseManager

    var body: some View {
        VStack {
            if let uuid = supabaseManager.uuid {
                LoggedInOnboardingView()
            } else {
                LoggedOutOnboardingView()
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
    return OnboardingView()
        .environmentObject(SupabaseManager())
}
