//
//  CanExecuteApplescript.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/18/24.
//

import Foundation

protocol CanExecuteApplescript: CanExecuteShellScript {
    func executeScript(script: String) async throws -> String
}

extension CanExecuteApplescript {
    func executeScript(script: String) async throws -> String {
        return try await executeShellScript(url: "/usr/bin/osascript", script: ["-e", script])
    }
}
