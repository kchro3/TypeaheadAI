//
//  ScreenshotManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/14/23.
//

import AppKit
import Foundation

class ScreenshotManager {
    func takeScreenshot(activeApp: NSRunningApplication) -> CGImage? {
        guard let windowListInfo = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], 
            kCGNullWindowID
        ) as NSArray? as? [[String: AnyObject]] else { return nil }

        let windowInfo = windowListInfo.first {
            $0[kCGWindowOwnerPID as String] as! Int32 == activeApp.processIdentifier &&
            $0[kCGWindowLayer as String] as! Int32 == 0
        }

        if let windowIDNumber = windowInfo?[kCGWindowNumber as String] as? NSNumber {
            let windowID = CGWindowID(windowIDNumber.uint32Value)
            guard let imageRef = CGWindowListCreateImage(
                CGRect.null, .optionIncludingWindow, windowID, .boundsIgnoreFraming
            ) else { return nil }

            return imageRef
        }

        return nil
    }
//
//    private func copyCGImageToClipboard(image: CGImage) {
//        let pasteboard = NSPasteboard.general
//        pasteboard.clearContents()
//
//        let bitmapRep = NSBitmapImageRep(cgImage: image)
//        let nsImage = NSImage(size: bitmapRep.size)
//        nsImage.addRepresentation(bitmapRep)
//
//        pasteboard.writeObjects([nsImage])
//    }
}
