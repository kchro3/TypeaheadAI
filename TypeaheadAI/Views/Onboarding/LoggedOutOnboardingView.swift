//
//  LoggedOutOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/11/23.
//

import SwiftUI

struct LoggedOutOnboardingView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var failedToSignIn: Bool = false
    @State private var failedToRegisterReason: String? = nil

    @ObservedObject var supabaseManager: SupabaseManager

    var body: some View {
        VStack(alignment: .center) {
            Image("SplashIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250)

            Spacer()

            Text("Welcome to Typeahead!")

            Spacer()

            Text("Please sign-in to get started.")

            Spacer()

            EmailAndPasswordView(
                email: $email,
                password: $password,
                showLabel: false
            )
            .frame(width: 250)

            Spacer()

            AccountOptionButton(label: "Sign in", isAccent: true, width: 250) {
                Task {
                    do {
                        try await supabaseManager.signinWithEmail(email: email, password: password)
                        email = ""
                        password = ""
                    } catch {
                        failedToRegisterReason = error.localizedDescription
                        failedToSignIn = true
                    }
                }
            }
            .alert(isPresented: $failedToSignIn, content: {
                Alert(title: Text("Failed to sign-in with email"), message: failedToRegisterReason.map { Text("\($0)") })
            })

            AccountOptionButton(label: "Sign-in with Apple", width: 250) {
                Task {
                    do {
                        try await supabaseManager.signinWithApple()
                    } catch {
                        failedToRegisterReason = error.localizedDescription
                        failedToSignIn = true
                    }
                }
            }
            .alert(isPresented: $failedToSignIn, content: {
                Alert(title: Text("Failed to sign-in with Apple"), message: failedToRegisterReason.map { Text("\($0)") })
            })

            AccountOptionButton(label: "Sign in with Google", isAccent: false, width: 250) {
                Task {
                    do {
                        try await supabaseManager.signinWithGoogle()
                    } catch {
                        failedToRegisterReason = error.localizedDescription
                        failedToSignIn = true
                    }
                }
            }
            .alert(isPresented: $failedToSignIn, content: {
                Alert(title: Text("Failed to sign-in with Google"), message: failedToRegisterReason.map { Text("\($0)") })
            })

            Spacer()

            Text("By continuing, you agree to Typeahead's Privacy Policy and Terms of Service.")
                .font(.caption)
        }
        .padding(30)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .center
        )
    }
}

#Preview {
    LoggedOutOnboardingView(supabaseManager: SupabaseManager())
        .frame(width: 400, height: 450)
}
