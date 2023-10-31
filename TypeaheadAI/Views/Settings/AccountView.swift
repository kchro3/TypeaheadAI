//
//  AccountView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/30/23.
//

import SwiftUI
import Supabase
import AuthenticationServices

struct NewAccountView: View {
    let failedToRegister: Binding<String?>
    let onSubmit: (String, String) -> Void
    let onCancel: () -> Void

    @Environment(\.colorScheme) var colorScheme

    @State private var newEmail: String = ""
    @State private var newPassword: String = ""

    private let descWidth: CGFloat = 80
    private let height: CGFloat = 200
    private let width: CGFloat = 300

    var body: some View {
        VStack(spacing: 15) {
            Text("New Account")
                .font(.title2)
                .fontWeight(.bold)

            HStack {
                Text("Email")
                    .frame(width: descWidth, alignment: .trailing)

                TextField("Email", text: $newEmail)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 15)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
            }

            HStack {
                Text("Password")
                    .frame(width: descWidth, alignment: .trailing)

                SecureField(text: $newPassword, label: {
                    Text("Password")
                })
                .textFieldStyle(.plain)
                .padding(.vertical, 5)
                .padding(.horizontal, 15)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
            }

            if let reason = failedToRegister.wrappedValue {
                Text(reason)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button(action: {
                    onCancel()
                }, label: {
                    Text("Cancel")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                        )
                })
                .buttonStyle(.plain)

                Button(action: {
                    onSubmit(newEmail, newPassword)
                }, label: {
                    Text("Create")
                        .padding(.vertical, 5)
                        .padding(.horizontal, 10)
                        .background(RoundedRectangle(cornerRadius: 15)
                            .fill(Color.accentColor)
                        )
                })
                .buttonStyle(.plain)
            }
        }
        .frame(width: width, height: height)
        .padding(15)
    }
}

struct AccountView: View {
    // Use this as a flag for checking if the user is signed in.
    @AppStorage("token3") var token: String?
    @AppStorage("uuid") var uuid: String?

    @Environment(\.colorScheme) var colorScheme

    @State private var isSignInVisible: Bool = false
    @State private var isHoveringSignOut: Bool = false
    @State private var isSheetPresented: Bool = false
    @State private var failedToRegisterReason: String? = nil
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var failedToSignIn: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private let descWidth: CGFloat = 80

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
            Text("Please sign-in to use online mode. Apple Sign-in is temporarily disabled.")
                .padding()

            HStack {
                Text("Email")
                    .frame(width: descWidth, alignment: .trailing)

                TextField("Email", text: $email)
                    .textFieldStyle(.plain)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 15)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                    )
                    .focused($isTextFieldFocused)
                    .onAppear {
                        isTextFieldFocused = true
                    }
            }

            HStack {
                Text("Password")
                    .frame(width: descWidth, alignment: .trailing)

                SecureField(text: $password, label: {
                    Text("Password")
                })
                .textFieldStyle(.plain)
                .padding(.vertical, 5)
                .padding(.horizontal, 15)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
            }

            Button {
                Task {
                    do {
                        let authResponse = try await supabase.auth.signIn(email: email, password: password)
                        let user = authResponse.user
                        uuid = user.id.uuidString
                        token = "placeholder"
                        let _ = try await supabase.auth.session
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
                    .padding(.horizontal, 10)
                    .background(RoundedRectangle(cornerRadius: 15)
                        .fill(Color.accentColor)
                    )
            }
            .buttonStyle(.plain)
            .alert(isPresented: $failedToSignIn, content: {
                Alert(title: Text("Failed to sign-in"), message: failedToRegisterReason.map { Text("\($0)") })
            })

            Button {
                isSheetPresented.toggle()
            } label: {
                Text("Sign up with email")
            }
            .sheet(isPresented: $isSheetPresented) {
                NewAccountView(failedToRegister: $failedToRegisterReason, onSubmit: { email, password in
                    Task {
                        do {
                            try await supabase.auth.signUp(email: email, password: password)
                            let session = try await supabase.auth.session
                            isSheetPresented = false

                            let user = session.user
                            uuid = user.id.uuidString
                            token = "placeholder"
                        } catch {
                            failedToRegisterReason = error.localizedDescription
                        }
                    }
                }, onCancel: {
                    isSheetPresented = false
                    failedToRegisterReason = nil
                })
            }
        }
    }

    @ViewBuilder
    var loggedInView: some View {
        VStack(alignment: .leading) {
            Text("You're signed in!")
                .padding()

            Text("User ID: \(uuid ?? "<not found>")")
                .padding()

            buttonRow(title: "Sign out", isHovering: $isHoveringSignOut) {
                token = nil
                uuid = nil
                Task {
                    try await supabase.auth.signOut()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    NewAccountView(failedToRegister: .constant(nil), onSubmit: { _, _ in }, onCancel: {})
}

#Preview {
    AccountView()
}
