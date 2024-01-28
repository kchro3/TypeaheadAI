//
//  PermissionsOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import SwiftUI

struct PermissionsOnboardingView: View {
    @State private var access = false

    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Getting Started")
            }

            Text(
            """
            Before we can get started, Typeahead will need some Accessibility permissions to work.

            In **System Settings**, under the **Privacy & Security** tab, please navigate to the **Accessibility** options and add Typeahead to your allowed apps.

            Press the button below to open System Preferences and modify your Accessibility settings.
            """
            )

            RoundedButton("Open System Preferences", isAccent: true) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                    NSWorkspace.shared.open(url)
                }
            }

            if access {
                HStack {
                    Text("Permissions have been granted!")

                    Image(systemName: "checkmark.circle")
                        .font(.title)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
            } else {
                HStack {
                    Text("Missing Accessibility Permissions")

                    Image(systemName: "xmark.circle")
                        .font(.title)
                        .foregroundStyle(.red)
                        .accessibilityHidden(true)
                }
            }

            Spacer()
        }
        .checkAccessibilityOnAppear(access: $access)
        .checkAccessibility(interval: 1, access: $access)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionsOnboardingView()
}
