//
//  IntroOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI

struct IntroOnboardingView: View {
    var body: some View {
        VStack {
            OnboardingHeaderView {
                Text("Introducing Typeahead AI")
            }

            Text(
            """
            VoiceOver is a nightmare to use. Navigating websites and apps is unintuitive, especially for new users. However, for the blind and visually impaired, there have been no good alternatives until now.

            Typeahead is the first AI screen reader that integrates ChatGPT with VoiceOver, and it is built to be accessibility-first.

            Let's give it a spin.
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
