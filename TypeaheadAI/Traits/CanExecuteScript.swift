//
//  CanExecuteScript.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/18/24.
//

import Foundation

protocol CanExecuteScript {
    func executeScript(script: String) async throws -> String
}

extension CanExecuteScript {
    func executeScript(script: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardOutput = pipe

            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: ApiError.appError("Failed to execute script"))
                }
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: ApiError.appError(error.localizedDescription))
            }
        }
    }
}
