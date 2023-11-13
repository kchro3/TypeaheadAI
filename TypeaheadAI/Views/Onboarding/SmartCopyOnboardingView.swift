//
//  SmartCopyOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI

struct SmartCopyOnboardingView: View {
    var body: some View {
        VStack {
            Text("Smart-copy")
                .font(.title)

            Spacer()

            Text("""
            The primary interface for Typeahead is smart-copy and smart-paste.

            For example, let's say you want to reply to this email. You can select the email below and smart-copy it with:
            """)
            .padding(.horizontal, 30)

            Spacer()

            HStack {
                HStack {
                    Text("Command")
                    Image(systemName: "command")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )

                HStack {
                    Text("Control")
                    Image(systemName: "control")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )

                HStack {
                    Text("C")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }

            Spacer()

            Text(
            """
            Hi,

            Thanks for trying out Typeahead! We are working on new features and fixing bugs every day, so we appreciate your support. Please let us know if you run into any issues.

            Best,
            The Typeahead Team
            """
            )
            .padding(10)
            .background(
                RoundedRectangle(cornerSize: CGSize(width: CGFloat(10), height: CGFloat(10)))
                    .fill(Color.accentColor.opacity(0.1))
            )
            .padding(.horizontal, 30)
            .textSelection(.enabled)

            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SmartCopyOnboardingView()
}
