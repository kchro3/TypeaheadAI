//
//  MessagePendingView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/27/23.
//

import SwiftUI

struct MessagePendingView: View {
    @State private var activeDotIndex = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
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
            .background(Color.secondary.opacity(0.2))
            .onReceive(timer) { _ in
                activeDotIndex = (activeDotIndex + 1) % 3
            }
        }
    }
}

struct MessagePendingView_Previews: PreviewProvider {
    static var previews: some View {
        MessagePendingView()
    }
}
