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
        if self.modalManager.isVisible {
            self.modalManager.closeModal()
            try await Task.sleep(for: .milliseconds(100))
        }

        let appInfo = try await self.appContextManager.getActiveAppInfo()

        let (tree, elementMap) = getUIElements(appContext: appInfo.appContext, inFocus: true)

        if let serialized = tree?.serialize() {
            print(serialized)
        }

        // Clear the current state
        self.modalManager.forceRefresh()
        self.modalManager.showModal()

        if let tree = tree, let point = tree.root.point, let size = tree.root.size {
            if let image = await captureScreen(point: point, size: size) {
                modalManager.appendUserImage(
                    image,
                    appContext: appInfo.appContext
                )
            } else {
                print("failed to get tiff representation")
            }
        } else {
            print("failed to get snapshot")
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
