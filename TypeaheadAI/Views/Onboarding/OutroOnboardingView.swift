//
//  OutroOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import MarkdownUI
import SwiftUI

struct OutroOnboardingView: View {
    let clientManager: ClientManager
    let supabaseManager: SupabaseManager

    var body: some View {
        VStack {
            OnboardingHeaderView {
                Text("Get Premium Mode")
            }

            Markdown(
                """
                Thank you for trying the demo, and we will continue to add more features and improve the overall experience!

                Please feel free to provide any feedback on the onboarding experience, and you can also reach out to me directly at jeff@typeahead.ai

                To access the latest AI models, upgrade to Premium Mode!
                """
            )

            AccountOptionButton(label: "Get Premium Mode", isAccent: true) {
                Task {
                    try await clientManager.createPaymentIntent(uuid: supabaseManager.uuid)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    return OutroOnboardingView(
        clientManager: ClientManager(), 
        supabaseManager: SupabaseManager()
    )
}
