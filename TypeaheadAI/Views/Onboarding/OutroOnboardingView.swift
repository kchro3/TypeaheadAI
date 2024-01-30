//
//  OutroOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import MarkdownUI
import SwiftUI

struct OutroOnboardingView: View {
    @Environment(\.colorScheme) var colorScheme

    @State var feedback: String = ""
    var onSubmit: ((String) async throws -> Void)? = nil

    @State private var showAlert = false
    @State private var errorMessage: String? = nil

    private let maxCharacterCount = 4000
    private let totalSteps: Int = 7

    @AppStorage("step") var step: Int = 1
    @AppStorage("hasOnboardedV4") var hasOnboarded: Bool = false

    init(onSubmit: ((String) async throws -> Void)? = nil) {
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack {
            OnboardingHeaderView {
                Text("You're all set!")
            }

            Markdown(
                """
                Thank you for trying the demo, and we will continue to add more features and improve the overall experience!

                Please feel free to provide any feedback on the onboarding experience, and you can also reach out to me directly at jeff@typeahead.ai
                """
            )

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    return OutroOnboardingView()
}
