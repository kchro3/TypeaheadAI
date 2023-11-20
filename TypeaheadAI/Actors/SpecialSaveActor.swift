//
//  SpecialSaveActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/11/23.
//

import Foundation
import SwiftUI
import os.log

enum SpecialSaveActorError: LocalizedError {
    case notImplemented(message: String)

    var errorDescription: String {
        switch self {
        case .notImplemented(let message): return message
        }
    }
}

actor SpecialSaveActor: CanSimulateSelectAll, CanSimulateCopy {
    private let appContextManager: AppContextManager
    private let modalManager: ModalManager
    private let clientManager: ClientManager
    private let memoManager: MemoManager
    private let settingsManager: SettingsManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialSaveActor"
    )

    init(
        appContextManager: AppContextManager,
        modalManager: ModalManager,
        clientManager: ClientManager,
        memoManager: MemoManager,
        settingsManager: SettingsManager
    ) {
        self.appContextManager = appContextManager
        self.modalManager = modalManager
        self.clientManager = clientManager
        self.memoManager = memoManager
        self.settingsManager = settingsManager
    }

    func specialSave() async throws {
        let appContext = try await self.appContextManager.getActiveAppInfo()

        print(appContext)

        guard let copiedText = NSPasteboard.general.string(forType: .string) else {
            // We can extend this by taking context from the screen
            throw SpecialSaveActorError.notImplemented(message: "User needs something highlighted next!")
        }

        print(copiedText)

        try await simulateCopy()
        guard let textToPaste = NSPasteboard.general.string(forType: .string) else {
            throw SpecialSaveActorError.notImplemented(message: "Something went wrong!")
        }

        print(textToPaste)

        await settingsManager.showModal(tab: Tab.quickActions)
    }
}
