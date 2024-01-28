//
//  ActivateOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/17/23.
//

import SwiftUI

struct ActivateOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("How to **activate** a Typeahead window")
            }

            Text(
                """
                The first thing you will need to learn is how to **activate** Typeahead.

                Typeahead runs in the **background**, so it will not be in your dock. Instead, it can be accessed by keyboard shortcut or from the menu bar.

                To open and close a Typeahead window, you can press the following keyboard shortcut.
                """
            )

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
                    Text("Space")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }
            .accessibilityElement()
            .accessibilityLabel("Option-Command-Space")
            .accessibilityHint("This shortcut can be reconfigured in your settings.")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ActivateOnboardingView()
}
