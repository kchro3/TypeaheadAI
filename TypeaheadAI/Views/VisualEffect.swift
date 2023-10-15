//
//  VisualEffect.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/3/23.
//

import Foundation
import SwiftUI

struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Self.Context) -> NSView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) { }
}
