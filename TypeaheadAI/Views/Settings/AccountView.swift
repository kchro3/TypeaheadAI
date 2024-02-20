//
//  AccountView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/30/23.
//

import MarkdownUI
import SwiftUI
import Supabase
import AuthenticationServices

struct AccountView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var supabaseManager: SupabaseManager
    let clientManager: ClientManager

    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Settings").font(.title)

            Divider()

            if self.supabaseManager.uuid == nil {
                // Logged-out view
                LoggedOutAccountView(supabaseManager: supabaseManager)
            } else if supabaseManager.isPremium {
                loggedInPremiumView
            } else {
                // Logged-in view
                loggedInView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .onAppear {
            Task {
                if let uuid = supabaseManager.uuid {
                    try await supabaseManager.checkAndSetUserStatus(uuid: uuid)
                }
            }
        }
    }

    @ViewBuilder
    var loggedInPremiumView: some View {
        VStack(alignment: .leading) {
            Text("Thank you for being a Premium user!")
                .padding()

            Spacer()

            HStack {
                AccountOptionButton(label: "Sign out") {
                    Task {
                        do {
                            try await supabaseManager.signout()
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("User ID: \(supabaseManager.uuid ?? "<none>")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var loggedInView: some View {
        VStack(alignment: .leading) {
            Text("You're signed in!")
                .padding()

            Spacer()
            
            HStack {
                AccountOptionButton(label: "Get Premium Mode", isAccent: true) {
                    Task {
                        try await clientManager.createPaymentIntent(uuid: supabaseManager.uuid)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                AccountOptionButton(label: "Sign out") {
                    Task {
                        do {
                            try await supabaseManager.signout()
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)

            HStack {
                Text("User ID: \(supabaseManager.uuid ?? "<none>")")
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
    AccountView(
        supabaseManager: SupabaseManager(),
        clientManager: ClientManager()
    )
}

#Preview {
    let manager = SupabaseManager()
    manager.uuid = "test"
    return AccountView(
        supabaseManager: manager,
        clientManager: ClientManager()
    )
}
