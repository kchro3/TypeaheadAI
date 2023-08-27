//
//  MenuPromptView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/23/23.
//

import SwiftUI

struct MenuPromptView: View {
    var prompt: String
    var isActive: Bool
    @State private var isHovering: Bool = false

    var body: some View {
        HStack {
            Image(systemName: isActive ? "paperclip.circle.fill" : "paperclip.circle")
                .resizable()
                .frame(width: 24, height: 24)
                .symbolRenderingMode(isActive ? .palette : .monochrome)
                .foregroundStyle(.primary, .blue)

            Text(prompt)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(isHovering ? Color.gray.opacity(0.4) : Color.clear)
        .cornerRadius(4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct MenuPromptView_Previews: PreviewProvider {
    static var previews: some View {
        MenuPromptView(prompt: "sample prompt", isActive: false)
        MenuPromptView(prompt: "sample prompt", isActive: true)
    }
}
