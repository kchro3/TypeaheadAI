//
//  AccountOptionButton.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/6/23.
//

import SwiftUI

struct AccountOptionButton: View {
    let label: String
    let isAccent: Bool
    let action: (() -> Void)?

    @State private var isHovering: Bool = false

    init(label: String, isAccent: Bool = false, action: (() -> Void)? = nil) {
        self.label = label
        self.isAccent = isAccent
        self.action = action
    }

    @Environment(\.colorScheme) var colorScheme
    private let width: CGFloat = 300

    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(label)
                    .foregroundStyle(isAccent ? .white : .primary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 20)
            .frame(width: width)
            .background(RoundedRectangle(cornerRadius: 15)
                .fill(
                    isAccent
                    ? Color.accentColor.opacity(isHovering ? 1.0 : 0.9)
                    : (colorScheme == .dark
                       ? .black.opacity(isHovering ? 0.3 : 0.2)
                       : .secondary.opacity(isHovering ? 0.25 : 0.15)))
            )
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .buttonStyle(.plain)
    }
}
#Preview {
    AccountOptionButton(label: "Sign in with Apple")
}
