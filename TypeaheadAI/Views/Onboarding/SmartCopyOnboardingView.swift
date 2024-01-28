//
//  SmartCopyOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import KeyboardShortcuts
import SwiftUI

struct SmartCopyOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("How to **smart-copy**")
            }

            Text("""
            One of Typeahead's workflows is **smart-copy** and **smart-paste**. It is smarter than your standard clipboard because it uses AI to take what you've copied and predict what you want to paste.

            For example, let's say you want to reply to the email below. You can select the text and **smart-copy** it with the following keyboard shortcut.
            """)

            KeyboardShortcuts.Recorder(for: .specialCopy)
                .accessibilityHint("You can also configure this in your settings.")

            Spacer()

            SampleEmailView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SmartCopyOnboardingView()
}
