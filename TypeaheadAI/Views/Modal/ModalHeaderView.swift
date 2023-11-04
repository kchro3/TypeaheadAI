//
//  ModalHeaderView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/3/23.
//

import SwiftUI

struct ModalHeaderView: View {
    @ObservedObject var modalManager: ModalManager

    @State private var isOnlineTooltipVisible: Bool = false
    @State private var isOnlineTooltipHovering: Bool = false

    @AppStorage("selectedModel") private var selectedModelURL: URL?

    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Button(action: {
                isOnlineTooltipVisible.toggle()
            }, label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(isOnlineTooltipHovering ? Color.accentColor : Color.secondary)
                    .onHover(perform: { hovering in
                        isOnlineTooltipHovering = hovering
                    })
            })
            .buttonStyle(.plain)
            .popover(isPresented: $isOnlineTooltipVisible, arrowEdge: .bottom) {
                Text("You can run TypeaheadAI in offline mode by running an LLM on your laptop locally, and you can toggle between online and offline modes here. Please see the Settings for detailed instructions on how to use offline mode.")
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300, maxHeight: 100)
            }

            Toggle("Online", isOn: $modalManager.online)
                .scaleEffect(0.8)
                .onChange(of: modalManager.online) { online in
                    if let manager = modalManager.clientManager?.llamaModelManager,
                       !online,
                       let _ = selectedModelURL {
                        manager.load()
                    }
                }
                .foregroundColor(Color.secondary)
                .toggleStyle(.switch)
                .accentColor(.blue)
                .padding(0)
        }
    }
}

#Preview {
    ModalHeaderView(modalManager: ModalManager())
}
