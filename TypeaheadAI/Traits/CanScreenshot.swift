//
//  CanScreenshot.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/18/23.
//

import Foundation

protocol CanScreenshot {
    func screenshot() async throws -> String?
}

extension CanScreenshot {
    func screenshot() async throws -> String? {
        let directory = NSTemporaryDirectory()
        let screenshotPath = NSURL.fileURL(withPathComponents: [directory, "capture_\(Date().ISO8601Format()).png"])!

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = [
            "-x", screenshotPath.path
        ]

        do {
            try task.run()
        } catch {
            return nil
        }

        task.waitUntilExit()
        return screenshotPath.path
    }
}
