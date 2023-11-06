//
//  NewAccountRegistrationForm.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/6/23.
//

import SwiftUI

struct NewAccountRegistrationForm: View {
    @Environment(\.colorScheme) var colorScheme

    @State var email: String = ""
    @State var password: String = ""
    private let supabaseManager: SupabaseManager
    private let onCancel: (() -> Void)?

    @State private var failedToSignIn: Bool = false
    @State private var failedToRegisterReason: String? = nil

    init(
        supabaseManager: SupabaseManager,
        onCancel: (() -> Void)? = nil
    ) {
        self.supabaseManager = supabaseManager
        self.onCancel = onCancel
    }

    var body: some View {
        VStack {
            EmailAndPasswordView(email: $email, password: $password)

            HStack {
                RoundedButton("Cancel", action: onCancel)
                RoundedButton("Register", isAccent: true) {
                    Task {
                        do {
                            try await supabaseManager.registerWithEmail(email: email, password: password)
                            email = ""
                            password = ""
                        } catch {
                            failedToRegisterReason = error.localizedDescription
                            failedToSignIn = true
                        }
                    }
                }
            }
            .alert(isPresented: $failedToSignIn, content: {
                Alert(title: Text("Failed to register"), message: failedToRegisterReason.map { Text("\($0)") })
            })
        }
        .padding()
    }
}

#Preview {
    NewAccountRegistrationForm(supabaseManager: SupabaseManager())
}
