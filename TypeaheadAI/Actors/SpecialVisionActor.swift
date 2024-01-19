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

    func specialVision() async throws {
        let appInfo = try await appContextManager.getActiveAppInfo()
        let (tree, _) = getUIElements(appContext: appInfo.appContext)

        guard let tree = tree, let point = tree.root.point, let size = tree.root.size else {
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
        } else {
            print("failed to get tiff representation")
        }

        await NSApp.activate(ignoringOtherApps: true)
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
