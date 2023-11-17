//
//  ScreenshotManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/15/23.
//

import AppKit
import Foundation
import Vision
import os.log

class ScreenshotManager {
    var task: Process?
    let screenCaptureURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "ScreenshotManager"
    )

    func takeScreenshot(activeApp: NSRunningApplication?) -> String? {
        let path = getScreenShotFilePath()
        task = Process()
        task?.executableURL = screenCaptureURL
        task?.arguments = [
            "-x", getScreenShotFilePath()
        ]

        do {
            try task?.run()
        } catch {
            self.logger.error("Failed to capture")
            task = nil
            return nil
        }

        task?.waitUntilExit()
        task = nil
        return path
    }

//        return NSImage(contentsOfFile: path)?.toCGImage()
        // NOTE: In the future, we should try to support only screenshotting the active window.
        //        guard let windowListInfo = CGWindowListCopyWindowInfo(
        //            [.optionOnScreenOnly],
        //            kCGNullWindowID
        //        ) as NSArray? as? [[String: AnyObject]] else { return nil }
        //
        //        let windowInfo = windowListInfo.first {
        //            $0[kCGWindowOwnerPID as String] as! Int32 == activeApp.processIdentifier &&
        //            $0[kCGWindowLayer as String] as! Int32 == 0
        //        }
        //
        //        if let windowIDNumber = windowInfo?[kCGWindowNumber as String] as? NSNumber {
        //            let windowID = CGWindowID(windowIDNumber.uint32Value)
        //            guard let imageRef = CGWindowListCreateImage(
        //                CGRect.null, .optionIncludingWindow, windowID, .boundsIgnoreFraming
        //            ) else { return nil }
        //
        //            return imageRef
        //        }
        //
        //        return nil
        //    }

    private func getScreenShotFilePath() -> String {
        let directory = NSTemporaryDirectory()
        return NSURL.fileURL(withPathComponents: [directory, "capture_\(Date().ISO8601Format()).png"])!.path
    }
}
