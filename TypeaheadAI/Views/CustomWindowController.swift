//
//  CustomWindowController.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/15/23.
//

import AppKit
import Foundation
import Cocoa
import SwiftUI

class CustomViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

struct CustomViewControllerRepresentable: NSViewControllerRepresentable {
    typealias NSViewControllerType = CustomViewController

    func makeNSViewController(context: Context) -> CustomViewController {
        return CustomViewController()
    }

    func updateNSViewController(_ nsViewController: CustomViewController, context: Context) {
        // Update any properties or configurations of the NSViewController here if needed
    }
}
