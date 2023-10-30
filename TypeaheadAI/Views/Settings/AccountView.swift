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
    @AppStorage("token2") var token: String?
    @AppStorage("uuid") var uuid: String?

    @State private var isSignInVisible: Bool = false
    @State private var isHoveringSignOut: Bool = false

    let supabase = SupabaseClient(
        supabaseURL: URL(string: "https://hwkkvezmbrlrhvipbsum.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3a2t2ZXptYnJscmh2aXBic3VtIiwicm9sZSI6ImFub24iLCJpYXQiOjE2OTgzNjY4NTEsImV4cCI6MjAxMzk0Mjg1MX0.aDzWW0p2uI7wsVGsu1mtfvEh4my8s9zhgVTr4r008YU")

    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Settings").font(.title)

            Divider()

            if token == nil {
                // Logged-out view
                loggedOutView
            } else {
                // Logged-in view
                loggedInView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }

    @ViewBuilder
    var loggedOutView: some View {
        VStack {
            Text("Please sign-in to use online mode.")

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task {
                    do {
                        guard let credential = try result.get().credential as? ASAuthorizationAppleIDCredential
                        else {
                            return
                        }

                        guard let idToken = credential.identityToken
                            .flatMap({ String(data: $0, encoding: .utf8) })
                        else {
                            return
                        }

                        token = idToken
                        try await supabase.auth.signInWithIdToken(
                            credentials: .init(
                                provider: .apple,
                                idToken: idToken
                            )
                        )

                        uuid = try? await supabase.auth.session.user.id.uuidString
                    } catch {
                        dump(error)
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .cornerRadius(25)
        }
    }

    @ViewBuilder
    var loggedInView: some View {
        VStack {
            Text("You're signed in through Apple iCloud!")
            Text("User ID: \(uuid ?? "<not found>")")

            buttonRow(title: "Sign out", isHovering: $isHoveringSignOut) {
                token = nil
                Task {
                    try await supabase.auth.signOut()
                }
            }
        }
    }

    private func buttonRow(
        title: String,
        isHovering: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
            .padding(4)
            .background(isHovering.wrappedValue ? .primary.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering.wrappedValue = hovering
        }
    }
}

#Preview {
    AccountView()
}
