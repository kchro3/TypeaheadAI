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

            

            Spacer()
        }
    }
}

#Preview {
    LoggedInOnboardingView(supabaseManager: SupabaseManager())
        .frame(width: 400, height: 450)
}
