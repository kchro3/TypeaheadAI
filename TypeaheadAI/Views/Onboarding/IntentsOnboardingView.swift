//
//  IntentsOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct IntentsOnboardingView: View {
    var body: some View {
        VStack {
            Text("Specify your **intent**")
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text("""
            In the chat window, you can tell Typeahead what to do with the copied data, and Typeahead may also try to suggest relevant actions.

            For this tutorial, you can click on the "reply to this email" suggestion.
            """)
            .padding(.horizontal, 30)

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
                    .fill(Color.accentColor.opacity(0.4))
            )
            .padding(30)
            .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    IntentsOnboardingView()
}
