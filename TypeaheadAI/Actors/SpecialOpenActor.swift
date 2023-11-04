//
//  SpecialOpenActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 10/5/23.
//

import AppKit
import Foundation
import os.log

actor SpecialOpenActor {
    private let clientManager: ClientManager
    private let appContextManager: AppContextManager
    private let modalManager: ModalManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialOpenActor"
    )

    init(
        clientManager: ClientManager,
        modalManager: ModalManager,
        appContextManager: AppContextManager
    ) {
        self.clientManager = clientManager
        self.appContextManager = appContextManager
        self.modalManager = modalManager
    }

    func specialOpen(forceRefresh: Bool = false) {
        if forceRefresh {
            self.logger.debug("special new")
        } else {
            self.logger.debug("special open")
        }

        self.appContextManager.getActiveAppInfo { appContext in
            Task {
                self.clientManager.currentAppContext = appContext
                if let isVisible = await self.modalManager.isWindowVisible(), !forceRefresh {
                    if !isVisible {
                        await self.modalManager.showModal()
                        await NSApp.activate(ignoringOtherApps: true)
                    } else {
                        await self.modalManager.closeModal()
                    }
                } else {
                    await self.modalManager.forceRefresh()
                    await self.modalManager.showModal()
                    await NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }
}
