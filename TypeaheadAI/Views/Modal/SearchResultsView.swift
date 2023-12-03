//
//  SearchResultsView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 12/2/23.
//

import MarkdownUI
import SwiftUI

struct SearchResultsView: View {
    @Environment(\.colorScheme) private var colorScheme

    var messages: [Message]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ForEach(messages.indices, id: \.self) { index in
                    MessageView(message: messages[index])
                        .padding(5)
                }
                .markdownTheme(.custom)
                .markdownCodeSyntaxHighlighter(.custom(
                    theme: colorScheme == .dark ? HighlighterConstants.darkTheme : HighlighterConstants.lightTheme
                ))
            }
        }
    }
}

#Preview {
    return SearchResultsView(messages: [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), text: "test message", isCurrentUser: true, isHidden: false, appContext: nil)
    ])
}
