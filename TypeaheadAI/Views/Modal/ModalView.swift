//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI

struct ModalView: View {
    @Binding var showModal: Bool

    var body: some View {
        VStack {
            Text("Special Copy Modal")
            Button("Close") {
                showModal = false
            }
        }
        .frame(width: 300, height: 200)
        .padding()
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true

    static var previews: some View {
        ModalView(showModal: $showModal)
    }
}
