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
        view.material = .hudWindow
        view.state = .active
        view.blendingMode = .behindWindow
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { }
}
