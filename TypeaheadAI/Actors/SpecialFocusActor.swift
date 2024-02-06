//
//  SpecialFocusActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/22/24.
//

import Cocoa
import Foundation
import os.log

actor SpecialFocusActor: CanGetUIElements {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialFocusActor"
    )

    private let appContextManager: AppContextManager
    private let modalManager: ModalManager

    init(
        appContextManager: AppContextManager,
        modalManager: ModalManager
    ) {
        self.appContextManager = appContextManager
        self.modalManager = modalManager
    }

    func specialFocus() async throws {
        guard NSWorkspace.shared.isVoiceOverEnabled else {
            return
        }

        if await !self.modalManager.isWindowVisible() {
            await self.modalManager.showModal()
        }

        await NSApp.activate(ignoringOtherApps: true)
        try await Task.sleep(for: .milliseconds(200))
        try await self.modalManager.stopDictation()

        await self.modalManager.forceRefresh()
        await self.modalManager.setText(
            NSLocalizedString("What element do you want to focus on?", comment: ""),
            isHidden: false,
            appContext: nil,
            messageContext: .focus
        )

        await self.modalManager.setPending(false)
    }
}
