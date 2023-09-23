//
//  MessageView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/23/23.
//

import SwiftUI
import Markdown

struct MessageView: View {
    let message: Message
    var onButtonDown: (() -> Void)?
    @State private var isExpanded: Bool = false

    init(
        message: Message,
        onButtonDown: (() -> Void)? = nil
    ) {
        self.message = message
        self.onButtonDown = onButtonDown
    }

    var body: some View {
        if let error = message.responseError, !message.isCurrentUser {
            HStack {
                Text(error)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color.red.opacity(0.4))
                    )

                Button(action: {
                    onButtonDown?()
                }, label: {
                    Image(systemName: "arrow.counterclockwise")
                })
                .buttonStyle(.plain)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else if let attributed = message.attributed {
            attributedView(results: attributed.results)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: message.isCurrentUser ? .trailing : .leading)
        } else if message.text.isEmpty && !message.isCurrentUser {
            Divider()
        } else if message.isCurrentUser {
            ZStack(alignment: .bottomTrailing) {
                Text((message.text.count < 280 || isExpanded) ? message.text : "\(String(message.text.prefix(280)))...\n")
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 15)
                    .background(RoundedRectangle(cornerRadius: 15).fill(Color.blue.opacity(0.8)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                Button(action: {
                    isExpanded.toggle()
                }, label: {
                    Text(isExpanded ? "See less" : "See more")
                        .foregroundColor(.white)
                })
                .buttonStyle(.plain)
                .padding(.vertical, 5)
                .padding(.horizontal, 15)
                .opacity(message.text.count < 280 ? 0 : 1)
                .disabled(message.text.count < 280)
            }
        } else {
            Text(message.text)
                .foregroundColor(.primary)
                .textSelection(.enabled)
                .padding(.vertical, 8)
                .padding(.horizontal, 15)
                .background(RoundedRectangle(cornerRadius: 15).fill(Color.clear))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    func attributedView(results: [ParserResult]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(results) { parsed in
                if parsed.isCodeBlock {
                    CodeBlockView(parserResult: parsed)
                        .padding(.bottom, 24)
                        .textSelection(.enabled)
                } else {
                    Text(parsed.attributedString)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

#Preview {
    MessageView(message: Message(id: UUID(), text: "hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot hello bot ", isCurrentUser: true))
}
