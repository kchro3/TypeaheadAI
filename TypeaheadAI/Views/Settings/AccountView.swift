//
//  AccountView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/30/23.
//

import SwiftUI
import Supabase
import AuthenticationServices

struct AccountView: View {
    // Use this as a flag for checking if the user is signed in.
    @AppStorage("token3") var token: String?
    @AppStorage("uuid") var uuid: String?

    @Environment(\.colorScheme) var colorScheme
    var supabaseManager: SupabaseManager

    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Settings").font(.title)

            Divider()

            if self.supabaseManager.uuid == nil {
                // Logged-out view
                LoggedOutAccountView(supabaseManager: supabaseManager)
            } else {
                // Logged-in view
                loggedInView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    @ViewBuilder
    var loggedInView: some View {
        VStack(alignment: .leading) {
            Text("You're signed in!")
                .padding()

            Text("Thanks for trying out TypeaheadAI! We are working on building new features, and we would appreciate your support.")
                .padding()

            Spacer()

            HStack {
                AccountOptionButton(label: "Sign out") {
                    Task {
                        try? await supabaseManager.signout()
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("User ID: \(uuid ?? "<none>")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AccountView(supabaseManager: SupabaseManager())
}
