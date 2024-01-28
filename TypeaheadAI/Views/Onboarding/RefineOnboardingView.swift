//
//  RefineOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct RefineOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Personalize your email")
            }

            if NSWorkspace.shared.isVoiceOverEnabled {
                Text(
            """
            You can see additional options if you right-click on a message. For example, you can edit a message or retry sending the message if there is a failure.

            Click continue when you're satisfied.
            """
                )

            } else {
                Text(
            """
            Edit your email by clicking the edit button next to the Typeahead response. Press **Enter** to save or **Shift-Enter** for a new line.

            Alternatively, you can type feedback like "make it more concise" or "more casual," and it will provide a revised draft.

            If you want it to remember detailed instructions for the future, you can click on the wrench icon to configure a Quick Action.

            Click continue when you're satisfied.
            """
                )
            }

            Spacer()

            SampleEmailView()
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RefineOnboardingView()
}
