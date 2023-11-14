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
                .font(.title)
                .padding(10)

            Text(
            """
            Welcome to the Typeahead tutorial!

            Unlike many apps, Typeahead runs in the **background**, so you won't see it in your dock. Instead, you'll see the Typeahead logo in the top menu bar when the app is running.

            The first thing you need to learn is how to **activate** Typeahead. You can open and close the Typeahead window with:
            """
            )

            Spacer()

            HStack {
                HStack {
                    Text("Control")
                    Image(systemName: "control")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )

                HStack {
                    Text("Command")
                    Image(systemName: "command")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )

                HStack {
                    Text("A")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }

            Spacer()


            Text(
            """
            Try opening and closing the window a few times to get used to it.

            You can move the window by dragging it by the top region of the window, and you can resize it by dragging its corners.
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
