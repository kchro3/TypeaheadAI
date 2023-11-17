//
//  ActivateOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/17/23.
//

import SwiftUI

struct ActivateOnboardingView: View {
    var body: some View {
        VStack {
            Text("How to **activate** a Typeahead window")
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text(
                """
                The first thing you will need to learn is how to **activate** Typeahead.

                Unlike many apps, Typeahead runs in the **background**, so you won't see it in your dock. Instead, you will see the Typeahead logo in the menu bar to indicate when the app is running.

                To open and close a Typeahead window, you can press:
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
            When you activate Typeahead, it will take a **screenshot** and try to get context on what you're doing.

            You can move the window by dragging it by the top region of the window, and you can resize it by dragging its corners.

            NOTE: All hotkeys can be reconfigured in your Settings.
            """
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ActivateOnboardingView()
}
