//
//  UserIntentsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/4/23.
//

import SwiftUI

/// NOTE: Singular, see below for the side-scrolling intent
struct UserIntentView: View {
    let userIntent: String
    let rank: Int
    let onButtonClick: ((String) -> Void)?
    let maxWidth: CGFloat = 250

    var body: some View {
        Button(action: {
            onButtonClick?(userIntent)
        }) {
            HStack {
                HStack(spacing: 2) {
                    Image(systemName: "command")
                    Text("\(rank)")
                }
                .accessibilityHidden(true)

                Text(userIntent)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 15)
            .frame(maxWidth: maxWidth)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.accentColor.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .id(UUID())  // Force resetting the view per load
        .keyboardShortcut(KeyEquivalent(Character("\(rank)")), modifiers: .command)
    }
}

struct UserIntentsView: View {
    let userIntents: [String]?
    let onButtonClick: ((String) -> Void)?

    var body: some View {
        if let userIntents = userIntents, userIntents.count > 0 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(userIntents.indices, id: \.self) { index in
                        UserIntentView(
                            userIntent: userIntents[index],
                            rank: index + 1,
                            onButtonClick: onButtonClick
                        )
                        .padding([.horizontal, .vertical], 5)
                    }
                }
            }
        } else {
            EmptyView()
        }
    }
}

#Preview {
    UserIntentsView(userIntents: ["Test", "This is a longer sentence", "How about a third sentence"], onButtonClick: nil)
        .frame(width: 400, height: 200)
}
