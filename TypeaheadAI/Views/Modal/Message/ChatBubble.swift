//
//  ChatBubble.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/27/23.
//

import Foundation
import SwiftUI

/// Copied from https://prafullkumar77.medium.com/swiftui-creating-a-chat-bubble-like-imessage-using-path-and-shape-67cf23ccbf62
struct ChatBubble<Content>: View where Content: View {
    let direction: ChatBubbleShape.Direction
    let content: () -> Content
    let onConfigure: (() -> Void)?
    let onEdit: (() -> Void)?
    let onRefresh: (() -> Void)?

    init(
        direction: ChatBubbleShape.Direction,
        onConfigure: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.onConfigure = onConfigure
        self.onEdit = onEdit
        self.onRefresh = onRefresh
        self.direction = direction
    }

    var body: some View {
        if direction == .right {
            userMessage
        } else {
            aiMessage
        }
    }

    @ViewBuilder
    var userMessage: some View {
        HStack(alignment: .bottom) {
            Spacer()

            userButtons
                .padding(.leading, 10)
                .accessibilityHidden(true)

            content()
                .clipShape(ChatBubbleShape(direction: direction))
                .contextMenu {
                    if let onEdit = onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Text("Edit Message")
                        }
                    }

                    if let onConfigure = onConfigure {
                        Button {
                            onConfigure()
                        } label: {
                            Text("Configure Quick Action")
                        }                        
                    }
                }
        }
    }

    @ViewBuilder
    var aiMessage: some View {
        HStack(alignment: .bottom) {
            content()
                .clipShape(ChatBubbleShape(direction: direction))
                .contextMenu {
                    if let onEdit = onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Text("Edit Message")
                        }
                    }

                    if let onRefresh = onRefresh {
                        Button {
                            onRefresh()
                        } label: {
                            Text("Retry")
                        }
                    }
                }

            aiButtons
                .padding(.trailing, 10)
                .accessibilityHidden(true)

            Spacer()
        }
    }

    @ViewBuilder
    var aiButtons: some View {
        HStack(spacing: 5) {
            editButton

            if let onButtonDown = onRefresh {
                Button(action: {
                    onButtonDown()
                }, label: {
                    Image(systemName: "arrow.counterclockwise")
                        .padding(.bottom, 8)
                })
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    var userButtons: some View {
        HStack(spacing: 5) {
            editButton

            configButton
        }
    }

    @ViewBuilder
    var editButton: some View {
        if let onEdit = onEdit {
            Button(action: {
                onEdit()
            }, label: {
                Image(systemName: "square.and.pencil")
            })
            .padding(.bottom, 10)
            .buttonStyle(.plain)
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    var configButton: some View {
        if let onConfigure = onConfigure {
            Button {
                onConfigure()
            } label: {
                Image(systemName: "wrench.adjustable")
            }
            .buttonStyle(.plain)
            .padding(.bottom, 7)
        } else {
            EmptyView()
        }
    }
}

struct ChatBubbleShape: Shape {
    enum Direction {
        case left
        case right
    }

    let direction: Direction

    func path(in rect: CGRect) -> Path {
        return (direction == .left) ? getLeftBubblePath(in: rect) : getRightBubblePath(in: rect)
    }

    private func getLeftBubblePath(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let path = Path { p in
            p.move(to: CGPoint(x: 25, y: height))
            p.addLine(to: CGPoint(x: width - 20, y: height))
            p.addCurve(to: CGPoint(x: width, y: height - 20),
                       control1: CGPoint(x: width - 8, y: height),
                       control2: CGPoint(x: width, y: height - 8))
            p.addLine(to: CGPoint(x: width, y: 20))
            p.addCurve(to: CGPoint(x: width - 20, y: 0),
                       control1: CGPoint(x: width, y: 8),
                       control2: CGPoint(x: width - 8, y: 0))
            p.addLine(to: CGPoint(x: 21, y: 0))
            p.addCurve(to: CGPoint(x: 4, y: 20),
                       control1: CGPoint(x: 12, y: 0),
                       control2: CGPoint(x: 4, y: 8))
            p.addLine(to: CGPoint(x: 4, y: height - 11))
            p.addCurve(to: CGPoint(x: 0, y: height),
                       control1: CGPoint(x: 4, y: height - 1),
                       control2: CGPoint(x: 0, y: height))
            p.addLine(to: CGPoint(x: -0.05, y: height - 0.01))
            p.addCurve(to: CGPoint(x: 11.0, y: height - 4.0),
                       control1: CGPoint(x: 4.0, y: height + 0.5),
                       control2: CGPoint(x: 8, y: height - 1))
            p.addCurve(to: CGPoint(x: 25, y: height),
                       control1: CGPoint(x: 16, y: height),
                       control2: CGPoint(x: 20, y: height))

        }
        return path
    }

    private func getRightBubblePath(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let path = Path { p in
            p.move(to: CGPoint(x: 25, y: height))
            p.addLine(to: CGPoint(x:  20, y: height))
            p.addCurve(to: CGPoint(x: 0, y: height - 20),
                       control1: CGPoint(x: 8, y: height),
                       control2: CGPoint(x: 0, y: height - 8))
            p.addLine(to: CGPoint(x: 0, y: 20))
            p.addCurve(to: CGPoint(x: 20, y: 0),
                       control1: CGPoint(x: 0, y: 8),
                       control2: CGPoint(x: 8, y: 0))
            p.addLine(to: CGPoint(x: width - 21, y: 0))
            p.addCurve(to: CGPoint(x: width - 4, y: 20),
                       control1: CGPoint(x: width - 12, y: 0),
                       control2: CGPoint(x: width - 4, y: 8))
            p.addLine(to: CGPoint(x: width - 4, y: height - 11))
            p.addCurve(to: CGPoint(x: width, y: height),
                       control1: CGPoint(x: width - 4, y: height - 1),
                       control2: CGPoint(x: width, y: height))
            p.addLine(to: CGPoint(x: width + 0.05, y: height - 0.01))
            p.addCurve(to: CGPoint(x: width - 11, y: height - 4),
                       control1: CGPoint(x: width - 4, y: height + 0.5),
                       control2: CGPoint(x: width - 8, y: height - 1))
            p.addCurve(to: CGPoint(x: width - 25, y: height),
                       control1: CGPoint(x: width - 16, y: height),
                       control2: CGPoint(x: width - 20, y: height))

        }
        return path
    }
}

#Preview {
    let markdownString = """
Dear Cynthia,

Thanks for trying out the app, really appreciate your candidness in the interviews.

Jeff
"""

    return ChatBubble(direction: .right) {

    } onEdit: {

    } onRefresh: {

    } content: {
        Text(markdownString)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .foregroundColor(.white)
            .background(Color.accentColor.opacity(0.8))
            .textSelection(.enabled)
    }
}

#Preview {
    let markdownString = """
Dear Cynthia,

Thanks for trying out the app, really appreciate your candidness in the interviews.

Jeff
"""

    return ChatBubble(direction: .left) {

    } onEdit: {

    } onRefresh: {

    } content: {
        Text(markdownString)
            .padding(.vertical, 10)
            .padding(.horizontal, 15)
            .foregroundColor(.white)
            .background(Color.accentColor.opacity(0.8))
            .textSelection(.enabled)
    }
}
