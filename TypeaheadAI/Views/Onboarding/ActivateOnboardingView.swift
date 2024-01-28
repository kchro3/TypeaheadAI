//
//  ActivateOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/17/23.
//

import KeyboardShortcuts
import SwiftUI

struct ActivateOnboardingView: View {
    @State private var isEditing: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("How to **activate** a Typeahead window")
            }

            Text(
                """
                Typeahead is a globally accessible chat window.

                Like VoiceOver, it pops up over other windows and is not in your dock.

                Instead, it can be toggled by keyboard shortcut.

                By default, the keyboard shortcut to open and close a Typeahead window is Option-Command-Space, but you can change it below.
                """
            )

            KeyboardShortcuts.Recorder(for: .chatOpen)
                .accessibilityHint("You can also configure this in your settings.")

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ActivateOnboardingView()
}
