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
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("How to **Smart-paste**")
            }

            Text(
            """
            Once you're happy with Typeahead's response, you can **smart-paste** the latest draft into Gmail or your favorite email app.

            For this tutorial, you can **smart-paste** the response into the text box below with:
            """
            )

            Spacer()

            HStack {
                HStack {
                    Text("Option")
                    Image(systemName: "option")
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
            .accessibilityElement()
            .accessibilityLabel("Option-Command-V")
            .accessibilityHint("This shortcut can be reconfigured in your settings.")

            Divider()
                .padding(10)

            TextEditor(text: $pastedContent)
                .font(.system(.body))
                .scrollContentBackground(.hidden)
                .lineLimit(nil)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(colorScheme == .dark ? .black.opacity(0.2) : .secondary.opacity(0.15))
                )
                .overlay(
                    Group {
                        if pastedContent.isEmpty {
                            Text(
                                """
                                Click here and press "smart-paste"
                                """
                            )
                            .foregroundColor(.secondary.opacity(0.4))
                            .padding(.top, 8)
                            .padding(.horizontal, 15)
                            .transition(.opacity)
                        }
                    }.allowsHitTesting(false),
                    alignment: .topLeading
                )
                .accessibilityElement()
                .accessibilityHint("Set focus on this element and press \"smart-paste.\"")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SmartPasteOnboardingView()
}
