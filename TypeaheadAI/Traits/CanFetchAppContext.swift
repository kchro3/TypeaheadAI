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

        let appName = activeApp.localizedName
        let bundleIdentifier = activeApp.bundleIdentifier
        return AppContext(
            appName: appName,
            bundleIdentifier: bundleIdentifier
        )
    }
}
