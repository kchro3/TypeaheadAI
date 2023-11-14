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

            Spacer()

            Text(
                """
                There are plenty of ways to get started!

                **Smart-copy** works on anything that you can copy, and **smart-paste** works anywhere that you can paste.

                It even works in full-screen apps, so it's always at your fingertips.

                You can access your settings from the menu bar.
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
                    Text("T")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OutroOnboardingView()
}
