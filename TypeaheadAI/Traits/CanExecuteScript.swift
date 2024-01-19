//
//  CanExecuteScript.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/18/24.
//

import Foundation

protocol CanExecuteScript {
    func executeScript(script: String) async -> String?
}

extension CanExecuteScript {
    func executeScript(script: String) async -> String? {
        await withCheckedContinuation { continuation in
            let task = Process()
            let pipe = Pipe()

            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            task.standardOutput = pipe

            task.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)
                continuation.resume(returning: output)
            }

            do {
                try task.run()
            } catch {
                print("An error occurred: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }
}
