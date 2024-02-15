//
//  CanExecuteShellScript.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 2/14/24.
//

import Foundation

protocol CanExecuteShellScript {
    func executeShellScript(url: String, script: [String]) async throws -> String
}

extension CanExecuteShellScript {
    func executeShellScript(url: String, script: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            task.executableURL = URL(fileURLWithPath: url)
            task.arguments = script
            task.standardOutput = outputPipe
            task.standardError = errorPipe  // Capture standard error

            task.terminationHandler = { _ in
                let exitStatus = task.terminationStatus
                if exitStatus == 0 {
                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        continuation.resume(returning: output)
                    } else {
                        continuation.resume(throwing: ApiError.appError("Failed to read script output"))
                    }
                } else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if let errorMessage = String(data: errorData, encoding: .utf8) {
                        continuation.resume(throwing: ApiError.appError(errorMessage))
                    } else {
                        continuation.resume(throwing: ApiError.appError("Script execution failed with exit status \(exitStatus)"))
                    }
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
