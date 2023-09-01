//
//  SplashView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/1/23.
//

import SwiftUI
import AppKit

struct SplashView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image("SplashIcon")
                Text("Welcome to TypeaheadAI's Alpha test!").font(.title)
            }

            VStack(alignment: .leading) {
                Text("How to use").font(.headline)
                Text("You can copy any text and \"smart-paste\" the result with command-control-V.")
                Text("You can also \"smart-copy\" with command-control-C to preview the result.")
            }

            VStack(alignment: .leading) {
                Text("Notes").font(.headline)
                Text("This app is still very buggy, so please reach out if you spot anything or have UX concerns.")
                Text("The app should update on its own, and I would appreciate any feedback.")
            }

            VStack(alignment: .leading) {
                Text("Tips").font(.headline)
                Text(" - The menu bar icon should flash if it's thinking.")
                Text(" - You can set \"goals\" in the menu bar to contextualize what you're trying to do.")
                Text(" - In the Settings, you can configure your key-mappings and see your history.")
            }
        }
        .padding(20)
        .textSelection(.enabled)
    }
}

struct SplashView_Previews: PreviewProvider {
    static var previews: some View {
        SplashView()
    }
}
