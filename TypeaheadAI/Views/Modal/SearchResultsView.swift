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

    private let dateFormatter = DateFormatter()
    private let calendar = Calendar.current

    var messages: [Message]
    var callback: ((UUID, UUID) -> Void)? = nil

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                ForEach(messages.indices, id: \.self) { index in
                    if index == 0 || messages[index-1].rootId != messages[index].rootId {
                        Divider()
                        HStack {
                            Spacer()

                            Text(relativeDateString(from: messages[index].createdAt))
                                .foregroundStyle(.secondary)

                            Spacer()
                        }
                        .padding(5)
                    }

                    HStack {
                        MessageView(message: messages[index])
                            .padding(5)

                        Button {
                            callback?(messages[index].rootId, messages[index].id)
                        } label: {
                            Image(systemName: "chevron.right")
                                .padding(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .markdownTheme(.custom)
                .markdownCodeSyntaxHighlighter(.custom(
                    theme: colorScheme == .dark ? HighlighterConstants.darkTheme : HighlighterConstants.lightTheme
                ))
            }
        }
    }

    func relativeDateString(from date: Date) -> String {
        if calendar.isDateInToday(date) {
            dateFormatter.dateFormat = "'Today' hh:mm a"
        } else if calendar.isDateInYesterday(date) {
            dateFormatter.dateFormat = "'Yesterday' hh:mm a"
        } else {
            dateFormatter.dateFormat = "MMM d, yyyy hh:mm a"
        }

        return dateFormatter.string(from: date)
    }
}

#Preview {
    return SearchResultsView(messages: [
        Message(id: UUID(), rootId: UUID(), inReplyToId: nil, createdAt: Date(), text: "test message", isCurrentUser: true, isHidden: false, appContext: nil)
    ])
}
