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

                You can change your keyboard shortcut configurations in the Settings, and you can manage your Quick Actions as well.
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
