//
//  LoggedOutAccountView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/6/23.
//

import SwiftUI

struct LoggedOutAccountView: View {
    // Use this as a flag for checking if the user is signed in.
    @AppStorage("token3") var token: String?
    @AppStorage("uuid") var uuid: String?

    @Environment(\.colorScheme) var colorScheme

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isSheetPresenting: Bool = false
    @State private var failedToSignIn: Bool = false
    @State private var failedToRegisterReason: String? = nil

    // Constants
    private let descWidth: CGFloat = 80
    private let fieldWidth: CGFloat = 250

    let supabaseManager: SupabaseManager

    var body: some View {
        VStack(alignment: .leading) {
            Text("Please sign-in to use TypeaheadAI in online mode.")

            VStack(spacing: 5) {
                loginWithEmail

                Spacer()

                AccountOptionButton(label: "Sign-in with Apple") {
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


                AccountOptionButton(label: "Sign-in with Google") {
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

                AccountOptionButton(label: "Register with email", isAccent: true) {
                    // Open up the modal window for registration
                    isSheetPresenting = true
                }
                .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .sheet(isPresented: $isSheetPresenting, content: {
                NewAccountRegistrationForm(supabaseManager: supabaseManager) {
                    // on cancel
                    isSheetPresenting = false
                }
            })

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder
    var loginWithEmail: some View {
        VStack {
            EmailAndPasswordView(email: $email, password: $password)

            HStack {
                Spacer()

                Button {
                    Task {
                        do {
                            let authResponse = try await supabaseManager.client.auth.signIn(email: email, password: password)
                            let user = authResponse.user
                            uuid = user.id.uuidString
                            token = "placeholder"
                            let _ = try await supabaseManager.client.auth.session
                            email = ""
                            password = ""
                        } catch {
                            failedToRegisterReason = error.localizedDescription
                            failedToSignIn = true
                        }
                    }
                } label: {
                    Text("Sign in")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 15)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor)
                        )
                }
                .buttonStyle(.plain)
                .alert(isPresented: $failedToSignIn, content: {
                    Alert(title: Text("Failed to sign-in"), message: failedToRegisterReason.map { Text("\($0)") })
                })
            }
            .frame(width: fieldWidth + 5 + descWidth)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    LoggedOutAccountView(supabaseManager: SupabaseManager())
}
