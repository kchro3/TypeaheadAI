//
//  SpecialVisionActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/12/24.
//

import Cocoa
import Foundation
import os.log

struct VOCursor: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var point: CGPoint {
        return CGPoint(x: x, y: y)
    }

    var size: CGSize {
        return CGSize(width: width, height: height)
    }
}

actor SpecialVisionActor: CanGetUIElements, CanExecuteScript {
    private static let voCursorScript = """
    tell application "VoiceOver"
        try
            set bound to bounds of vo cursor -- Attempt to get bounds of VO cursor
            set outputString to "{\\"x\\": " & item 1 of bound & ", \\"y\\": " & item 2 of bound & ", \\"width\\": " & (item 3 of bound) - (item 1 of bound) & ", \\"height\\": " & (item 4 of bound) - (item 2 of bound) & "}"
            return outputString
        on error errMsg
            return errMsg -- Return message if an error occurs
        end try
    end tell
    """

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialVisionActor"
    )

    private let appContextManager: AppContextManager
    private let modalManager: ModalManager
    private let clientManager: ClientManager

    init(
        appContextManager: AppContextManager,
        modalManager: ModalManager,
        clientManager: ClientManager
    ) {
        self.appContextManager = appContextManager
        self.modalManager = modalManager
        self.clientManager = clientManager
    }

    func specialVision() async throws {
        // Clear the current state
        await self.modalManager.forceRefresh()

        let appInfo = try await appContextManager.getActiveAppInfo()
        guard let (point, size) = await getPointAndSize(appContext: appInfo.appContext) else {
            await self.modalManager.showModal()
            await modalManager.setError(NSLocalizedString("Failed to get screenshot boundaries", comment: ""), appContext: appInfo.appContext)

            await NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let image = captureScreen(point: point, size: size) {
            await self.modalManager.showModal()

            // Add user image
            await modalManager.appendUserImage(
                image,
                appContext: appInfo.appContext
            )

            try await modalManager.replyToUserMessage()
        } else {
            await self.modalManager.showModal()
            await modalManager.setError(NSLocalizedString("Failed to get screenshot", comment: ""), appContext: appInfo.appContext)
        }

        await NSApp.activate(ignoringOtherApps: true)
    }

    /// NOTE: This is getting complicated because I'm trying to log some error messages to see why the cursor is not being read correctly.
    /// Once it gets cleaned up, we can remove the clientManager calls, and we can simplify the error handling logic.
    func getPointAndSize(appContext: AppContext?) async -> (CGPoint, CGSize)? {
        if NSWorkspace.shared.isVoiceOverEnabled {
            /// If VoiceOver is enabled, then attempt to get the VO cursor bounds
            var serializedCursorOrError: String? = nil
            do {
                serializedCursorOrError = try await executeScript(script: SpecialVisionActor.voCursorScript)
            } catch let error as ApiError {
                Task {
                    try? await clientManager.sendFeedback(
                        feedback: "Failed to get cursor: \(error.errorDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            } catch {
                Task {
                    try? await clientManager.sendFeedback(
                        feedback: "Failed to get cursor: \(error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }

            if let data = serializedCursorOrError?.data(using: .utf8),
               let cursor = try? JSONDecoder().decode(VOCursor.self, from: data) {
                return (cursor.point, cursor.size)
            } else {
                if let error = serializedCursorOrError {
                    Task {
                        try? await clientManager.sendFeedback(
                            feedback: "Failed to get cursor: \(error.trimmingCharacters(in: .whitespacesAndNewlines))")
                    }
                }
            }
        }

        let (tree, _) = getUIElements(appContext: appContext)
        if let tree = tree, let point = tree.root.point, let size = tree.root.size {
            return (point, size)
        } else {
            return nil
        }
    }

    func captureScreen(point: CGPoint, size: CGSize) -> ImageData? {
        let rect = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)

        guard let screenshot = CGWindowListCreateImage(
            rect, .optionOnScreenOnly, kCGNullWindowID, .boundsIgnoreFraming
        ) else {
            return nil
        }

        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        let nsImage = NSImage(cgImage: screenshot, size: imageSize)
        return nsImage.downscale(toWidth: 1024)
            .b64JPEG(compressionFactor: 0.75)
    }
}
