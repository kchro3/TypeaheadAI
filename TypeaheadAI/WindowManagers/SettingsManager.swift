//
//  SettingsManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/17/23.
//

import AppKit
import SwiftUI
import Foundation
import os.log

class SettingsManager: ObservableObject {
    var toastWindow: ModalWindow?
    var promptManager: QuickActionManager? = nil
    var llamaModelManager: LlamaModelManager? = nil
    var supabaseManager: SupabaseManager? = nil

    private let context: NSManagedObjectContext

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SettingsManager"
    )

    @AppStorage("settingsTab") var settingsTab: String?
    @AppStorage("hasOnboardedV4") var hasOnboarded: Bool = false

    init(context: NSManagedObjectContext) {
        self.context = context

        startMonitoring()
    }

    private func startMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.loginAndOpenWindow(_:)),
            name: .oAuthCallback,
            object: nil
        )
    }

    @MainActor
    func showModal(tab: Tab? = nil) {
        toastWindow?.close()

        if let tab = tab {
            settingsTab = tab.id
        }

        // Create the visual effect view with frosted glass effect
        let visualEffect = NSVisualEffectView()
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.material = .hudWindow

        let contentView = SettingsView(
            promptManager: promptManager!, 
            llamaModelManager: llamaModelManager!,
            supabaseManager: supabaseManager!
        )
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
            hostingView.topAnchor.constraint(equalTo: baseView.topAnchor, constant: -28), // Offset by the size of the menu bar
            hostingView.bottomAnchor.constraint(equalTo: baseView.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: baseView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: baseView.trailingAnchor)
        ])

        toastWindow?.setFrame(NSRect(x: 0, y: 0, width: 600, height: 500), display: true)
        toastWindow?.center()

        toastWindow?.titlebarAppearsTransparent = true
        toastWindow?.isReleasedWhenClosed = false
        toastWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func loginAndOpenWindow(_ notification: NSNotification) {
        guard hasOnboarded else {
            self.logger.info("Deferring... needs to onboard")
            return
        }

        guard let url = notification.userInfo?["url"] as? URL else { return }

        Task {
            try await self.supabaseManager?.signinWithURL(from: url)
            await self.showModal(tab: Tab.account)
        }
    }
}
