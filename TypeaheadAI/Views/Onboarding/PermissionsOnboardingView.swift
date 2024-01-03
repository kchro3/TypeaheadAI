//
//  PermissionsOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import SwiftUI

struct PermissionsOnboardingView: View {
    var body: some View {
        VStack {
            Text("Getting Started")
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text(
            """
            Before we can get started, Typeahead will need some Accessibility permissions to work.

            In **System Settings**, under the **Privacy & Security** tab, please navigate to the **Accessibility** options and add Typeahead to your allowed apps.

            Press the button below to open System Preferences and modify your Accessibility settings.
            """
            )

            Spacer()

            RoundedButton("Open System Preferences", isAccent: true) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionsOnboardingView()
}
