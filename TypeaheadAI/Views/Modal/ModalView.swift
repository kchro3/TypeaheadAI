//
//  ModalView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 8/31/23.
//

import SwiftUI

struct ModalView: View {
    @Binding var showModal: Bool
    @ObservedObject var copyModalManager: ModalManager
    @State private var fontSize: CGFloat = 14.0

    var body: some View {
        ZStack {
            ScrollView {
                Text(copyModalManager.modalText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .font(.system(size: fontSize))
                    .foregroundColor(Color.primary)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if let savedFontSize = UserDefaults.standard.value(forKey: "UserFontSize") as? CGFloat {
                fontSize = savedFontSize
            }
        }
        .foregroundColor(Color.secondary.opacity(0.2))
    }
}

struct ModalView_Previews: PreviewProvider {
    @State static var showModal = true

    static var previews: some View {
        let copyModalManager = ModalManager()
        copyModalManager.setText("hello world")
        return ModalView(showModal: $showModal, copyModalManager: copyModalManager)
    }
}
