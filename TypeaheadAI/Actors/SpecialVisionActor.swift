//
//  SpecialVisionActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/12/24.
//

import Cocoa
import Foundation
import os.log

actor SpecialVisionActor: CanGetUIElements {
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

    @MainActor
    func specialVision() async throws {
        let appInfo = try await appContextManager.getActiveAppInfo()
        let (tree, elementMap) = getUIElements(appContext: appInfo.appContext)

        guard let tree = tree, let point = tree.root.point, let size = tree.root.size else {
            return
        }

        if let image = await captureScreen(point: point, size: size) {
            // Clear the current state
            self.modalManager.forceRefresh()
            self.modalManager.showModal()

            // Add user image
            modalManager.appendUserImage(
                image,
                appContext: appInfo.appContext
            )
        } else {
            print("failed to get tiff representation")
        }
    }

    func captureScreen(point: CGPoint, size: CGSize) -> Data? {
        let rect = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)

        guard let screenshot = CGWindowListCreateImage(
            rect, .optionOnScreenOnly, kCGNullWindowID, .boundsIgnoreFraming
        ) else {
            return nil
        }

        let imageSize = CGSize(width: screenshot.width, height: screenshot.height)
        return NSImage(cgImage: screenshot, size: imageSize).tiffRepresentation
    }
}
