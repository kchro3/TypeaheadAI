//
//  EmailAndPasswordView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/6/23.
//

import SwiftUI

struct EmailAndPasswordView: View {
    @Binding var email: String
    @Binding var password: String

    @Environment(\.colorScheme) var colorScheme

    // Constants
    private let descWidth: CGFloat = 80
    private let fieldWidth: CGFloat = 250

    init(email: Binding<String>, password: Binding<String>) {
        self._email = email
        self._password = password
    }

    var body: some View {
        VStack {
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
                    .frame(width: fieldWidth)
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
                .frame(width: fieldWidth)
            }
        }
    }
}

#Preview {
    EmailAndPasswordView(email: .constant("email@email.com"), password: .constant("password"))
}
