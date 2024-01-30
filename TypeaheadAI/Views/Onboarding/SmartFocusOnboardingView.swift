//
//  SmartFocusOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/28/24.
//

import KeyboardShortcuts
import MarkdownUI
import SwiftUI

struct SmartFocusOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("Using Typeahead with VoiceOver")
            }

            Markdown("""
            When using VoiceOver, it can be cumbersome to find a button or an element, so you can ask Typeahead to set the focus on something for you.

            By pressing **Option-Command-F**, you can tell Typeahead where you want to focus, and Typeahead will try move the VoiceOver cursor. You can describe the button or text field you are looking for, like "search button" or "log-in button."

            Note that this feature only works when VoiceOver is enabled.
            """)

            KeyboardShortcuts.Recorder(for: .specialFocus) {
                Text("Smart-Focus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityHint("You can also configure this in your settings.")
            .padding(.horizontal, 30)

            Spacer()
        }
    }
}

#Preview {
    SmartFocusOnboardingView()
}
