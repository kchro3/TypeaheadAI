//
//  ActivateOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/17/23.
//

import KeyboardShortcuts
import MarkdownUI
import SwiftUI

struct ActivateOnboardingView: View {
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Typeahead Basics")
            }

            Markdown(
                """
                Typeahead is a **globally accessible** chat window. It can handle text or voice input, so you can ask it questions or tell it to do something for you.

                Like VoiceOver, the chat window sits on top of other windows and can access the main application. To open and close the Typeahead window, you can use a keyboard shortcut, which is **Option-Command-Space** by default.

                When you send a message, Typeahead will think for a couple seconds and then respond with text and voice. You can cancel a response by pressing **Command-Escape**.
                """
            )

            Markdown(
                """
                Let's give it a try. Press **Option-Command-Space** to open the chat window. Then type or say "summarize content" and press enter to send.
                """
            )

            Text("You can reconfigure the shortcuts below or in your settings later.")

            VStack {
                KeyboardShortcuts.Recorder(for: .chatOpen) {
                    Text("Open the chat window")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityHint("You can also configure this in your settings.")

                KeyboardShortcuts.Recorder(for: .cancelTasks) {
                    Text("Cancel Tasks")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityHint("You can also configure this in your settings.")
            }
            .padding(.horizontal, 30)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ActivateOnboardingView()
}
