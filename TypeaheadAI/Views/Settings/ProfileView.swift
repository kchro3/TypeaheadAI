//
//  ProfileView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/8/23.
//

import SwiftUI
import AppKit

struct ProfileView: View {
    @AppStorage("bio") private var bio: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Profile").font(.title).textSelection(.enabled)

                Divider()

                Text("What should TypeaheadAI know about you to provide better responses?").font(.headline)

                TextEditor(text: $bio)
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(5)
                    .frame(height: 50)

                Divider()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
