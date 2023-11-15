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
                .font(.title)
                .padding(10)

            Text(
            """
            The next thing we need to do is grant some permissions.

            In order for Typeahead to work, you will need to go into your **System Settings**, then to the **Privacy & Security** tab, and finally to the **Accessibility** options.

            You may also press the button below to request the permissions. (Note: this only needs to be done once, so if you have already granted permissions, then nothing will happen when you press the button.)
            """
            )

            Spacer()

            RoundedButton("Check Accessibility Permissions", isAccent: true) {
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
