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
            When you're using VoiceOver, it can be annoying to find a button or an element. You can use Typeahead to control the VoiceOver cursor.


            """)

            KeyboardShortcuts.Recorder(for: .specialCopy)
                .accessibilityHint("You can also configure this in your settings.")

            Spacer()

            SampleEmailView()
        }
    }
}

#Preview {
    SmartFocusOnboardingView()
}
