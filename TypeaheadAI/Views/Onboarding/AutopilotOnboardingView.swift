//
//  AutopilotOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/2/24.
//

import KeyboardShortcuts
import MarkdownUI
import SwiftUI

struct AutopilotOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Autopilot Mode")
            }

            Markdown(
            """
            Next, we will show you how to use **Autopilot**. Typeahead can do simple multi-step tasks for you, like filling out forms and sending emails.

            It knows how to **open apps and websites** and **interact with the UI**. You can tell it what to do in plain English, and it will try to carry out the task on its own. If it gets stuck or needs more clarification, it will ask for help.

            This is still in early development, so we appreciate your patience if there are bugs. If you don't want it, you can disable it in the settings.

            Let's give it a try. Open a new window with the keyboard shortcut **Option-Command-N** and say or type "Check Microsoft's stock on Yahoo Finance"
            """
            )

            KeyboardShortcuts.Recorder(for: .chatNew) {
                Text("New Chat")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityHint("You can also configure this in your settings.")
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

#Preview {
    AutopilotOnboardingView()
}
