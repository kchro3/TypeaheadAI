//
//  QuickActionExplanationOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct QuickActionExplanationOnboardingView: View {
    var body: some View {
        VStack {
            Text("Why use smart-copy and smart-paste?")
                .font(.title)

            Spacer()

            Text(
            """
            At its core, **smart-copy** and **smart-paste** is an **interface** to make AI more accessible, but it also learns how you like to work.

            Every time you **smart-copy** and **smart-paste** something, Typeahead will use the copied input and the pasted output as an example for how to do that task again.

            For example, if the AI-generated email wasn't quite right, you could **manually edit** the draft or **prompt** it some more (e.g. "make it more casual").

            When you're happy with the latest draft, you can **smart-paste** the email, and your preferences will be saved for the next time you reply to an email.
            """
            )
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

#Preview {
    QuickActionExplanationOnboardingView()
}
