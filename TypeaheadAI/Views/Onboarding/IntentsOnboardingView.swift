//
//  IntentsOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct IntentsOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Specify your **intent**")
            }

            Text("""
            In the chat window, you can tell Typeahead what to do with the copied data, and Typeahead may also try to suggest relevant actions.

            For this tutorial, you can click on the "reply to this email" suggestion.
            """)

            Spacer()

            SampleEmailView()
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    IntentsOnboardingView()
}
