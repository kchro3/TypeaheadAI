//
//  ModalManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/2/23.
//

import AppKit
import Foundation

class ModalManager: ObservableObject {
    @Published var modalText: String = ""

    func hasText() -> Bool {
        return !modalText.isEmpty
    }

    func clearText() {
        modalText = ""
    }

    func setText(_ text: String) {
        modalText = text
    }

    func appendText(_ text: String) {
        modalText += text
    }
}
