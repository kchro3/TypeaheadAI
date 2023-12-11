//
//  CanFetchAppContext.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/20/23.
//

import AppKit
import Foundation

protocol CanFetchAppContext {
    func fetchAppContext() async throws -> AppContext?
}

extension CanFetchAppContext {
    func fetchAppContext() async throws -> AppContext? {
        guard let activeApp = NSWorkspace.shared.menuBarOwningApplication else {
            return nil
        }

        return AppContext(
            appName: activeApp.localizedName,
            bundleIdentifier: activeApp.bundleIdentifier,
            pid: activeApp.processIdentifier
        )
    }
}
