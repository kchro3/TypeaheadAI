//
//  CopyButtonView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/19/23.
//

import SwiftUI

struct CopyButtonView: View {
    let onCopy: (() -> Void)?
    @State var isCopied = false

    var body: some View {
        if isCopied {
            Image(systemName: "checkmark.circle")
                .imageScale(.large)
                .symbolRenderingMode(.multicolor)
        } else {
            Button {
                onCopy?()

                withAnimation {
                    isCopied = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isCopied = false
                    }
                }
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .foregroundColor(.white)
        }
    }
}

#Preview {
    CopyButtonView(onCopy: {})
}
