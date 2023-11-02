//
//  UserIntentsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/4/23.
//

import SwiftUI

struct UserIntentsView: View {
    let userIntents: [String]
    let onButtonClick: ((String) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(userIntents.indices, id: \.self) { index in
                    intent(for: index)
                        .padding([.horizontal, .vertical], 5)
                }
            }
        }
    }

    private func intent(for index: Int) -> some View {
        Button(action: {
            onButtonClick?(userIntents[index])
        }) {
            Text(userIntents[index])
                .foregroundStyle(.white)
                .lineLimit(1)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.accentColor.opacity(0.4))
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UserIntentsView(userIntents: ["Test", "This is a longer sentence", "How about a third sentence"], onButtonClick: nil)
        .frame(width: 400, height: 200)
}
