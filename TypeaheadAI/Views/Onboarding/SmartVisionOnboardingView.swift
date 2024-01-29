//
//  SmartVisionOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/28/24.
//

import KeyboardShortcuts
import MarkdownUI
import SwiftUI

struct SmartVisionOnboardingView: View {
    var body: some View {
        VStack(spacing: 20) {
            OnboardingHeaderView {
                Text("How to use **Smart-Vision**")
            }

            Markdown("""
            When you're using VoiceOver, some elements like pictures and icons may not be labeled properly, so you may want to ask Typeahead to describe it for you.

            You can take a screenshot of what is currently under VoiceOver's cursor, and Typeahead will describe what it sees.
            """)

            KeyboardShortcuts.Recorder(for: .specialVision) {
                Text("Smart-Vision")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityHint("You can also configure this in your settings.")
            .padding(.horizontal, 30)

            Spacer()

            Image("OnboardingImage")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250)
        }
    }
}

#Preview {
    SmartVisionOnboardingView()
}
