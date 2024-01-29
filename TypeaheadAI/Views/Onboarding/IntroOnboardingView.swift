//
//  IntroOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI
import MarkdownUI

struct IntroOnboardingView: View {
    var body: some View {
        VStack {
            OnboardingHeaderView {
                Text("Introducing Typeahead AI")
            }

            Markdown(
            """
            Navigating websites and apps with VoiceOver is hard, especially for new users. However, for the blind and visually impaired, there have been no good solutions until now.

            **Typeahead** is the first AI screen reader that integrates ChatGPT with VoiceOver, and it is built to be **accessibility-first**.

            Here are just a few things you can do:

            - You can tell Typeahead where to set the VoiceOver cursor, like on a search bar or a log-in button.
            - You can ask Typeahead to summarize what's on the screen.
            - You can ask Typeahead to take a screenshot of the VO cursor.
            - You can ask Typeahead to do simple workflows.

            Let's get started!
            """
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    IntroOnboardingView()
}
