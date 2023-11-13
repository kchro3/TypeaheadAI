//
//  SmartPasteOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct SmartPasteOnboardingView: View {
    @Environment(\.colorScheme) var colorScheme

    @State private var pastedContent: String = ""

    var body: some View {
        VStack {
            Text("Smart-paste")
                .font(.title)

            Spacer()

            Text(
            """
            In the chat window, you can tell Typeahead what to do with the copied data, and Typeahead will also try to suggest relevant actions.

            In this case, you can tell it to "reply to the email"

            Typeahead will try to generate an email, which you can paste with:
            """
            )
            .padding(.horizontal, 30)

            Spacer()

            HStack {
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
                    Text("V")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }

            Spacer()

            TextEditor(text: $pastedContent)
                .font(.system(.body))
                .scrollContentBackground(.hidden)
                .lineLimit(nil)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
//                .background(RoundedRectangle(cornerRadius: 15)
//                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
//                )
//                .overlay(
//                    Group {
//                        if pastedContent.isEmpty {
//                            Text(
//                                    """
//                                    Click here and press "smart-copy"
//                                    """)
//                            .foregroundColor(.secondary.opacity(0.4))
//                            .padding(.top, 8)
//                            .padding(.horizontal, 15)
//                            .transition(.opacity)
//                        }
//                    },
//                    alignment: .topLeading
//                )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SmartPasteOnboardingView()
}
