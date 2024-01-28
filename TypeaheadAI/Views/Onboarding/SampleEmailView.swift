//
//  SampleEmailView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/27/24.
//

import SwiftUI

struct SampleEmailView: View {
    var body: some View {
        Text(
            """
            Hi,

            Thanks for trying out Typeahead! We are working on new features and fixing bugs every day, so we appreciate your support. Please let us know if you run into any issues.

            Best,
            The Typeahead Team
            """
        )
        .padding(10)
        .background(
            RoundedRectangle(cornerSize: CGSize(width: CGFloat(10), height: CGFloat(10)))
                .fill(Color.accentColor.opacity(0.4))
        )
        .textSelection(.enabled)
        .accessibilityHint("Try selecting this email and press command-option-C to \"smart-copy.\"")
    }
}

#Preview {
    SampleEmailView()
}
