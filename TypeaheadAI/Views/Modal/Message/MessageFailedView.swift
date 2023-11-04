//
//  MessageFailedView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/4/23.
//

import SwiftUI

struct MessageFailedView: View {
    let error: String
    var onRefresh: (() -> Void)? = nil

    var body: some View {
        HStack {
            // Message itself (wrap in a chat?)
            Text(error)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.red.opacity(0.4))
                )

            if let onRefresh = onRefresh {
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview {
    MessageFailedView(error: "This is a test failure") {
        // Placeholder
    }
}
