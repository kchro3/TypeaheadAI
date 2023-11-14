//
//  OutroOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI

struct OutroOnboardingView: View {
    var body: some View {
        VStack {
            Text("You're all set!")
                .font(.title)
                .padding(10)

            Text(
                """
                There are plenty of ways to get started! You can think of Typeahead as a new tool in your toolkit, where you can ask it to convert meeting notes into follow-up emails or summarize news articles, and it is like a copilot for all of your apps.

                **Smart-copy** works on anything that you can copy, and **smart-paste** works anywhere that you can paste.

                It even works in full-screen apps, so it's always at your fingertips.

                You can access your settings from the menu bar.
                """
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OutroOnboardingView()
}
