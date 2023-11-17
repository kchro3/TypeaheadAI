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
            Text("How to use Typeahead")
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text(
            """
            Typeahead is an **AI-powered clipboard** for Mac.

            In this short tutorial, you will learn about Typeahead's basic features.

            We will also explain how Typeahead works behind the scenes.
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
