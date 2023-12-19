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
            Before we can get started, Typeahead will need some Accessibility permissions to use your clipboard and to use Autopilot mode.

            In **System Settings**, under the **Privacy & Security** tab, please navigate to the **Accessibility** options and add Typeahead to your allowed apps.

            You may also press the button below to request these permissions. If you have already granted permissions, the button will not do anything.
            """
            )

            Spacer()

            RoundedButton("Check Accessibility Permissions", isAccent: true) {
                // Simulate a key press to trigger permission request
                let source = CGEventSource(stateID: .hidSystemState)!
                let cmdCDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)!
                cmdCDown.post(tap: .cghidEventTap)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionsOnboardingView()
}
