//
//  MessagePendingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/27/23.
//

import SwiftUI

struct MessagePendingView: View {
    let isPending: Bool

    @State private var activeDotIndex = 0
    @Environment(\.colorScheme) private var colorScheme

    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if isPending {
                ChatBubble(direction: .left) {
                    HStack(spacing: 2) {
                        ForEach(0..<3) { index in
                            Image(systemName: "circle.fill")
                                .font(.footnote)
                                .foregroundColor(Color.secondary.opacity(activeDotIndex == index ? 0.6 : 0.3))
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.trailing, 10)
                    .padding(.leading, 15)
                    .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.secondary.opacity(0.15))
                    .onReceive(timer) { _ in
                        activeDotIndex = (activeDotIndex + 1) % 3
                    }
                }
                .padding(3)
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    MessagePendingView(isPending: true)
}

#Preview {
    MessagePendingView(isPending: false)
}
