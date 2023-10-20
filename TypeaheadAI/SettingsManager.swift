//
//  SettingsManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/17/23.
//

import AppKit
import SwiftUI
import Foundation

class SettingsManager: ObservableObject {
    var toastWindow: ModalWindow?
    var promptManager: PromptManager? = nil
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    @MainActor
    func showModal() {
        toastWindow?.close()

        // Create the visual effect view with frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow

        let contentView = SettingsView(promptManager: promptManager!)
            .environment(\.managedObjectContext, context)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // Create a base view to hold both the visualEffect and hostingView
        let baseView = NSView()

        // Create the window
        toastWindow = ModalWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 200),
            styleMask: [
                .closable,
                .miniaturizable,
                .fullSizeContentView,
                .resizable,
                .titled
            ],
            backing: .buffered,
            defer: false
        )

        // Set the base effect view as the window's content view
        toastWindow?.contentView = baseView

        // Now that baseView has a frame, set the frames for visualEffect and hostingView
        visualEffect.frame = baseView.bounds
        visualEffect.autoresizingMask = [.width, .height]

        hostingView.frame = baseView.bounds

        // Add visualEffect and hostingView to baseView
        baseView.addSubview(visualEffect)
        baseView.addSubview(hostingView)

        // Add constraints to make the hosting view fill the base view
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: baseView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor)
        ])

        toastWindow?.setFrame(NSRect(x: 0, y: 0, width: 600, height: 500), display: true)
        toastWindow?.center()

        toastWindow?.titlebarAppearsTransparent = true
        toastWindow?.isReleasedWhenClosed = false
        toastWindow?.makeKeyAndOrderFront(nil)

        toastWindow?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
}
