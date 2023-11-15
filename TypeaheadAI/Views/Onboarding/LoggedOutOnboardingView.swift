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
    @State private var isSheetPresenting: Bool = false

    @ObservedObject var supabaseManager: SupabaseManager

    var body: some View {
        VStack(alignment: .center) {
            Image("SplashIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250)

            Spacer()

            Text("Please register or sign-in to get started.")

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

            AccountOptionButton(label: "Continue with Apple", width: 250) {
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

            AccountOptionButton(label: "Continue with Google", isAccent: false, width: 250) {
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

            AccountOptionButton(label: "New user? Register with email.", width: 250) {
                isSheetPresenting = true
            }
            .sheet(isPresented: $isSheetPresenting, content: {
                NewAccountRegistrationForm(supabaseManager: supabaseManager) {
                    // on cancel
                    isSheetPresenting = false
                }
            })

            Spacer()

            HStack(spacing: 0) {
                Text("By continuing, you agree to Typeahead's ")
                    .font(.caption)
                Link("Privacy Policy", destination: URL(string: "https://typeahead.ai/privacy-policy")!)
                    .font(.caption)
                    .foregroundStyle(.primary)
                Text(" and ")
                    .font(.caption)
                Link("Terms of Use", destination: URL(string: "https://typeahead.ai/terms-of-use")!)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
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
