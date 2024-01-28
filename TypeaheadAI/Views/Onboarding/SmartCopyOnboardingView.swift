//
//  SmartCopyOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI

struct SmartCopyOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("How to **smart-copy**")
            }

            Text("""
            One of Typeahead's workflows is **smart-copy** and **smart-paste**. It is smarter than your standard clipboard because it uses AI to take what you've copied and predict what you want to paste.

            For example, let's say you want to reply to the below email. You can select the text and **smart-copy** it with the following keyboard shortcut.
            """)

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
                    Text("C")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }
            .accessibilityElement()
            .accessibilityLabel("Option-Command-C")
            .accessibilityHint("This shortcut can be reconfigured in your settings.")

            Spacer()

            SampleEmailView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SmartCopyOnboardingView()
}
