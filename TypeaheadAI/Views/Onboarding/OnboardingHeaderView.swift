//
//  OnboardingHeaderView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/27/24.
//

import SwiftUI

struct OnboardingHeaderView: View {
    @AccessibilityFocusState var isFocused: Bool
    var header: Text

    init(@ViewBuilder text: () -> Text) {
        self.header = text()
    }

    var body: some View {
        header
            .font(.largeTitle)
            .padding(.vertical, 10)
            .accessibilityAddTraits(.isHeader)
            .accessibilityFocused($isFocused)
            .onAppear {
                isFocused = true
            }
    }
}

#Preview {
    OnboardingHeaderView {
        Text("Title")
    }
}
