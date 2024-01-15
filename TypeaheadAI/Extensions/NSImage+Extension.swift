//
//  NSImage+Extension.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/13/24.
//

import Cocoa
import Foundation

extension NSImage {
    func downscale(toWidth width: CGFloat) -> NSImage {
        let originalSize = self.size
        let scaleFactor = width / originalSize.width
        let newHeight = originalSize.height * scaleFactor
        let newSize = CGSize(width: width, height: newHeight)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        self.draw(in: CGRect(origin: .zero, size: newSize), from: CGRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        newImage.unlockFocus()

        return newImage
    }

    func b64PNG() -> ImageData? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            print("Failed to get CGImage from NSImage")
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to get PNG representation of the image")
            return nil
        }

        return ImageData.b64Json(pngData.base64EncodedString())
    }

    func b64JPEG(compressionFactor: CGFloat = 1.0) -> ImageData? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor]) else {
            return nil
        }

        return ImageData.b64Json(jpegData.base64EncodedString())
    }
}
