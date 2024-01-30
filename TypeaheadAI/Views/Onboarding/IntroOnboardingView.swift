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

            - Summarize what's happening on the screen.
            - Set the VoiceOver cursor onto a search bar or a login-button.
            - Take a screenshot of the VO cursor and describe what's happening.
            - Execute simple workflows.

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
