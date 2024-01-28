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
                Text("Welcome to Typeahead")
            }

            Text(
            """
            Typeahead is an AI tool that automates your busywork.

            In this tutorial, you will learn about Typeahead's basic features, and we will explain how Typeahead works behind the scenes.

            In this version, we are introducing "Autopilot" mode, where you can record and automate your workflows.
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
