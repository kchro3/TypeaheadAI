//
//  AccountView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/30/23.
//

import SwiftUI
import AuthenticationServices

struct AccountView: View {
    @AppStorage("token") var token: String?

    @State private var isSignInVisible: Bool = false
    @State private var isHoveringSignOut: Bool = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("Account Settings").font(.title)

            Divider()

            Text(token == nil ? "You are not signed in." : "You're signed in through Apple iCloud!")

            if token == nil {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authResults):
                        if let appleIDCredential = authResults.credential as? ASAuthorizationAppleIDCredential,
                           let authorizationToken = appleIDCredential.authorizationCode,
                           let tokenString = String(data: authorizationToken, encoding: .utf8) {
                            token = tokenString
                        }
                    case .failure(let error):
                        // TODO: Show some error message
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .cornerRadius(25)
            } else {
                buttonRow(title: "Sign out", isHovering: $isHoveringSignOut) {
                    token = nil
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
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
