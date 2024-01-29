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
        on error
            return "{}" -- Return empty JSON if an error occurs
        end try
    end tell
    """

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialVisionActor"
    )

    private let appContextManager: AppContextManager
    private let modalManager: ModalManager

    init(
        appContextManager: AppContextManager,
        modalManager: ModalManager
    ) {
        self.appContextManager = appContextManager
        self.modalManager = modalManager
    }

    func specialVision() async throws {
        let appInfo = try await appContextManager.getActiveAppInfo()
        guard let (point, size) = await getPointAndSize(appContext: appInfo.appContext) else {
            return
        }

        if let image = captureScreen(point: point, size: size) {
            // Clear the current state
            await self.modalManager.forceRefresh()
            await self.modalManager.showModal()

            // Add user image
            await modalManager.appendUserImage(
                image,
                appContext: appInfo.appContext
            )

            try await modalManager.prepareUserInput()
        } else {
            await modalManager.setError(NSLocalizedString("Failed to get screenshot", comment: ""), appContext: appInfo.appContext)
        }
    }

    func getPointAndSize(appContext: AppContext?) async -> (CGPoint, CGSize)? {
        if NSWorkspace.shared.isVoiceOverEnabled {
            /// If VoiceOver is enabled, then get the VO cursor bounds
            if let serializedCursor = await executeScript(script: SpecialVisionActor.voCursorScript),
               let data = serializedCursor.data(using: .utf8),
               let cursor = try? JSONDecoder().decode(VOCursor.self, from: data) {
                return (cursor.point, cursor.size)
            } else {
                return nil
            }
        } else {
            let (tree, _) = getUIElements(appContext: appContext)
            if let tree = tree, let point = tree.root.point, let size = tree.root.size {
                return (point, size)
            } else {
                return nil
            }
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
