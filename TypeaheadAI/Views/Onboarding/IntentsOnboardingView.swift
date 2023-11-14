//
//  IntentsOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/13/23.
//

import SwiftUI

struct IntentsOnboardingView: View {
    var body: some View {
        VStack {
            Text("Specify your intent")
                .font(.title)

            Spacer()

            Text("""
            In the chat window, you can tell Typeahead what to do with the copied data, and Typeahead may also try to suggest relevant actions.

            For this tutorial, you can click on the "reply to this email" suggestion.

            Now, Typeahead will try to generate an email reply.
            """)
            .padding(.horizontal, 30)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    IntentsOnboardingView()
}
