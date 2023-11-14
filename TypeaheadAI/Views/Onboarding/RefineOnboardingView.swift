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
                .font(.title)
                .padding(10)

            Text(
            """
            Typeahead will generate a first draft, but you can customize the email by manually editing it or by providing feedback in the chat.

            To manually edit, click on the edit button next to the Typeahead response. You can press **Enter** to save your changes. To add a new line, you can press **Shift-Enter**.

            To prompt-edit, you can type in feedback like: "make it more concise" or "more casual". Typeahead will then generate a new draft based on your feedback.

            If you're happy with the email, press continue.
            """
            )
            .padding(.horizontal, 30)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RefineOnboardingView()
}
