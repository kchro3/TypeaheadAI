//
//  SpecialRecordActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/8/23.
//

import Cocoa
import Foundation
import os.log

actor SpecialRecordActor: CanSimulateScreengrab, CanPerformOCR {
    private let appContextManager: AppContextManager

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialRecordActor"
    )

    init(
        appContextManager: AppContextManager
    ) {
        self.appContextManager = appContextManager
    }

    func specialRecord() {
        self.appContextManager.getActiveAppInfo { appContext in
            Task {
                try self.simulateScreengrab {
                    guard let tiffData = NSPasteboard.general.data(forType: .tiff),
                          let image = NSImage(data: tiffData),
                          let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                        self.logger.error("Failed to retrieve image from clipboard")
                        return
                    }

                    self.performOCR(image: cgImage) { recognizedText, imageWithBoxes in
                        print(recognizedText)
                        if let imageWithBoxes = imageWithBoxes {
                            NSPasteboard.general.setData(imageWithBoxes.tiffRepresentation, forType: .tiff)
                        }
                    }
                }
            }
        }
    }

    func simulateMouseClick(at point: CGPoint) {
        let mouseDownEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)
        mouseDownEvent?.post(tap: .cghidEventTap)

        let mouseUpEvent = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
        mouseUpEvent?.post(tap: .cghidEventTap)
    }
}
