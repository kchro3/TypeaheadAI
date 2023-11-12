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
    private let showLabel: Bool

    init(
        email: Binding<String>,
        password: Binding<String>,
        showLabel: Bool = true
    ) {
        self._email = email
        self._password = password
        self.showLabel = showLabel
    }

    var body: some View {
        if showLabel {
            withLabel
        } else {
            withoutLabel
        }
    }

    @ViewBuilder
    var withLabel: some View {
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

    /// NOTE: I prefer the view without the label. We can remove the label on the Account page later.
    @ViewBuilder
    var withoutLabel: some View {
        VStack {
            TextField("Email", text: $email)
                .textFieldStyle(.plain)
                .padding(.vertical, 5)
                .padding(.horizontal, 15)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )

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
    }
}

#Preview {
    EmailAndPasswordView(email: .constant("email@email.com"), password: .constant("password"))
}

#Preview {
    EmailAndPasswordView(email: .constant(""), password: .constant(""), showLabel: false)
}
