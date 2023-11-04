//
//  MenuButtonView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/4/23.
//

import SwiftUI
import KeyboardShortcuts

struct MenuButtonView: View {
    let title: String
    let shortcut: KeyboardShortcuts.Name?
    let action: (() -> Void)?

    @State private var isHovering: Bool = false

    init(
        title: String,
        shortcut: KeyboardShortcuts.Name? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.shortcut = shortcut
        self.action = action
    }

    var body: some View {
        Button {
            self.action?()
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut?.shortcut?.description ?? "")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(4)
            .background(isHovering ? .primary.opacity(0.2) : Color.clear)
            .cornerRadius(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

#Preview {
    MenuButtonView(title: "Test")
}

#Preview {
    MenuButtonView(title: "Test")
}
