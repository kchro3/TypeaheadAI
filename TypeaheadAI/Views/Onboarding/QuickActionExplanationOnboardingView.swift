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
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text(
            """
            Let's break down what happened behind the scenes.

            At its core, **smart-copy** and **smart-paste** is an **interface** to make AI more accessible, but it also learns how you like to work.

            Every time you **smart-copy** and **smart-paste** something, Typeahead will use the copied input and the pasted output as an example for how to do that task again.

            For example, if you edited the email manually or by prompting, your preferences would be remembered for the next time you say "reply to this email." It can learn to generalize patterns across examples, and the more you use Typeahead, the better it will become.
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
