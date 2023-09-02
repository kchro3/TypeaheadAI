//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI

struct ModalView: View {
    @Binding var showModal: Bool
    @ObservedObject var copyModalManager: CopyModalManager

    var body: some View {
        ZStack {
            ScrollView {
                Text(copyModalManager.modalText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .foregroundColor(Color.primary)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .foregroundColor(Color.secondary.opacity(0.2))
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true

    static var previews: some View {
        let copyModalManager = CopyModalManager()
        copyModalManager.setText("hello world")
        return ModalView(showModal: $showModal, copyModalManager: copyModalManager)
    }
}
