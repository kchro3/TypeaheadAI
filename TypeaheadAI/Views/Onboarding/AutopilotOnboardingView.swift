//
//  AutopilotOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/2/24.
//

import SwiftUI

struct AutopilotOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Autopilot Mode")
            }

            Text(
            """
            Next, we will show you how to use **Autopilot**. Typeahead can do your busywork for you, like filling out forms and even sending emails.

            It knows how to **open apps and websites** and **interact with the UI**, so you can think of it like a self-driving car. You can tell it what to do, and it will try to carry out the task on its own. If it gets stuck or needs more clarification, it will ask for help.

            This is still in early development, so we appreciate your patience if there are bugs. If you don't want it, you can disable it in the settings.

            Let's give it a try. Open a new window with:
            """
            )

            HStack {
                HStack {
                    Text("Option")
                    Image(systemName: "option")
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
                    Text("N")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }
            .padding(.vertical, 20)

            Text(
            """
            and type "Check Microsoft's stock"
            """
            )
        }
    }
}

#Preview {
    AutopilotOnboardingView()
}
