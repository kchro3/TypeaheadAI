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
    private let maxCharacterCount = 500

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Text("Profile").font(.title).textSelection(.enabled)

                Divider()

                Text("What should TypeaheadAI know about you to provide better responses?").font(.headline)

                TextEditor(text: $bio)
                    .onChange(of: bio) { newValue in
                        if newValue.count > maxCharacterCount {
                            bio = String(newValue.prefix(maxCharacterCount))
                        }
                    }
                    .padding(10)
                    .background(Color.white)
                    .cornerRadius(5)
                    .lineSpacing(5)
                    .frame(minHeight: 50, maxHeight: 200)

                Text("Character count: \(bio.count)/\(maxCharacterCount)")
                    .font(.footnote)
                    .foregroundColor(bio.count > maxCharacterCount ? .red : .primary)

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
