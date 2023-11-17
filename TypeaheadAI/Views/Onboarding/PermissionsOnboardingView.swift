//
//  PermissionsOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import SwiftUI

struct PermissionsOnboardingView: View {
    private let screenshotManager = ScreenshotManager()

    var body: some View {
        VStack {
            Text("Getting Started")
                .font(.largeTitle)
                .padding(.vertical, 10)

            Text(
            """
            Before we can get started, Typeahead will need some permissions in order to use your clipboard and to see what's on your screen, but it will only use your clipboard and your screen when you activate it.

            In **System Settings**, under the **Privacy & Security** tab, please navigate to the **Accessibility** options and add Typeahead to your allowed apps.

            Then please navigate to the **Screen Sharing** option and add Typeahead to your allowed apps. This will require you to restart the app.

            You may also press the buttons below to request these permissions. If you have already granted permissions, the buttons will not do anything.
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

            RoundedButton("Check Screen Sharing Permissions", isAccent: true) {
                // Take a screenshot to trigger permission request
                _ = screenshotManager.takeScreenshot(activeApp: nil)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    PermissionsOnboardingView()
}
