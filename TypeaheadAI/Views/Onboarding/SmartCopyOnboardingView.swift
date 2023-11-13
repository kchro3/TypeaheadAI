//
//  SmartCopyOnboardingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/12/23.
//

import SwiftUI

struct SmartCopyOnboardingView: View {
    var body: some View {
        VStack {
            Text("Smart-copy")
                .font(.title)

            Spacer()

            Text("You can select text and smart-copy it with:")

            Spacer()

            HStack {
                HStack {
                    Text("Command")
                    Image(systemName: "command")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )

                HStack {
                    Text("Control")
                    Image(systemName: "control")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )

                HStack {
                    Text("C")
                }
                .padding(5)
                .cornerRadius(5)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white, lineWidth: 1)
                )
            }

            Spacer()

            Text("Try selecting and smart-copying the following text:")

            Text("""
            
            """)

            Spacer()

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

    }
}

#Preview {
    SmartCopyOnboardingView()
}
