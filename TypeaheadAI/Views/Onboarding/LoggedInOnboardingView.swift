//
//  LoggedInOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/6/23.
//

import SwiftUI

struct LoggedInOnboardingView: View {
    @ObservedObject var supabaseManager: SupabaseManager

    var body: some View {
        VStack(alignment: .center) {
            Image("SplashIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 250)

            Spacer()

            if let user = supabaseManager.user {
                if user.productId == 0 {
                    subscribe
                } else {
                    Text("This subscription is not supported in this version.")
                }
            } else {
                Text("Unable to sign-in. Please check your Internet connection or restart the app.")
            }
        }
    }

    @ViewBuilder
    private var subscribe: some View {
        RoundedButton("Subscribe", isAccent: true) {
            Task {
                try await supabaseManager.openStripeCheckout()
            }
    }
}

#Preview {
    LoggedInOnboardingView(supabaseManager: SupabaseManager())
        .frame(width: 400, height: 450)
}

#Preview {
    var supabaseManager = SupabaseManager()
    supabaseManager.user = TypeaheadUser(uuid: UUID(), productId: 0)

    return LoggedInOnboardingView(supabaseManager: supabaseManager)
        .frame(width: 400, height: 450)
}
