//
//  RefineOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct RefineOnboardingView: View {
    var body: some View {
        VStack {
            Text("Personalize your email")
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text(
            """
            Edit your email by clicking the edit button next to the Typeahead response. Press **Enter** to save or **Shift-Enter** for a new line.

            Alternatively, you can type feedback like "make it more concise" or "more casual," and it will provide a revised draft.

            If you want it to remember detailed instructions for the future, you can click on the wrench icon to configure a Quick Action.

            Click continue when you're satisfied.
            """
            )
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
    RefineOnboardingView()
}
