//
//  RoundedButton.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/6/23.
//

import SwiftUI

struct RoundedButton: View {
    @Environment(\.colorScheme) var colorScheme

    let label: String
    let isAccent: Bool
    let action: (() -> Void)?

    init(
        _ label: String,
        isAccent: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.label = label
        self.isAccent = isAccent
        self.action = action
    }

    var body: some View {
        Button(action: {
            action?()
        }, label: {
            Text(label)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .foregroundStyle(isAccent ? .white : .primary)
                .background(RoundedRectangle(cornerRadius: 15)
                    .fill(isAccent ? Color.accentColor
                          : (colorScheme == .dark 
                             ? .black.opacity(0.2)
                             : .secondary.opacity(0.15)))
                )
        })
        .buttonStyle(.plain)
    }
}

#Preview {
    RoundedButton("Cancel")
}
