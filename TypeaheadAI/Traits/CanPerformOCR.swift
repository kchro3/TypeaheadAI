//
//  CanPerformOCR.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/15/23.
//

import AppKit
import Foundation
import Vision

private struct Constants {
    static let thresholdX: CGFloat = 0.01
    static let thresholdY: CGFloat = 0.02
}

protocol CanPerformOCR {
    func performOCR(image: CGImage) async throws -> (String, NSImage?)
}

extension CanPerformOCR {
    func performOCR(image: CGImage) async throws -> (String, NSImage?) {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: NSError(domain: "OCR", code: 0, userInfo: [NSLocalizedDescriptionKey: "No text observations found"]))
                    return
                }

                let groupedBoxesAndTexts = self.groupBoundingBoxes(observations)
                let allRecognizedText = groupedBoxesAndTexts.map { $0.text }.joined(separator: "\n")
                let imageWithBoxes = self.drawBoundingBoxes(around: observations, in: image)

                continuation.resume(returning: (allRecognizedText, imageWithBoxes))
            }

            request.recognitionLevel = .accurate
            request.automaticallyDetectsLanguage = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Function to group recognized text bounding boxes based on overlaps
    private func groupBoundingBoxes(_ observations: [VNRecognizedTextObservation]) -> [(box: CGRect, text: String)] {
        let boxesAndTexts = observations.map { (box: $0.boundingBox.insetBy(dx: -Constants.thresholdX, dy: -Constants.thresholdY), text: $0.topCandidates(1).first?.string ?? "") }

        // Create sets for overlapping boxes
        var overlappingSets: [Set<Int>] = []
        for (i, boxAndText1) in boxesAndTexts.enumerated() {
            var set: Set<Int> = [i]
            for (j, boxAndText2) in boxesAndTexts.enumerated() {
                if i != j && boxAndText1.box.intersects(boxAndText2.box) {
                    set.insert(j)
                }
            }
            overlappingSets.append(set)
        }

        if overlappingSets.count == 0 {
            return []
        }

        // Merge overlapping sets without replacement
        var mergedSets: [Set<Int>] = [overlappingSets.removeFirst()]
        while !overlappingSets.isEmpty {
            var wasMerged = false
            for (index, set) in overlappingSets.enumerated() {
                if let targetIndex = mergedSets.firstIndex(where: { !$0.isDisjoint(with: set) }) {
                    mergedSets[targetIndex].formUnion(set)
                    overlappingSets.remove(at: index)
                    wasMerged = true
                    break
                }
            }
            if !wasMerged {
                mergedSets.append(overlappingSets.removeFirst())
            }
        }

        // Combine the bounding boxes of merged sets into a single observation and gather texts
        var groupedBoxesAndTexts: [(box: CGRect, texts: [(box: CGRect, text: String)])] = []
        for set in mergedSets {
            var unionBox = CGRect.null
            var texts: [(box: CGRect, text: String)] = []
            for index in set {
                unionBox = unionBox.union(boxesAndTexts[index].box)
                texts.append(boxesAndTexts[index])
            }
            groupedBoxesAndTexts.append((box: unionBox, texts: texts))
        }

        // Sort the grouped bounding boxes from up-to-down, left-to-right
        groupedBoxesAndTexts.sort { (group1, group2) -> Bool in
            if group1.box.origin.y != group2.box.origin.y {
                return group1.box.origin.y > group2.box.origin.y // Sort by y-axis (descending)
            }
            return group1.box.origin.x < group2.box.origin.x // Then by x-axis (ascending)
        }

        // Sort the inner bounding boxes' text from top-to-bottom, left-to-right as well
        for i in 0..<groupedBoxesAndTexts.count {
            groupedBoxesAndTexts[i].texts.sort { (text1, text2) -> Bool in
                if text1.box.origin.y != text2.box.origin.y {
                    return text1.box.origin.y > text2.box.origin.y // Sort by y-axis (descending)
                }
                return text1.box.origin.x < text2.box.origin.x // Then by x-axis (ascending)
            }
        }

        // Convert the grouped boxes and texts into the required format
        let result = groupedBoxesAndTexts.map { (group: (box: CGRect, texts: [(box: CGRect, text: String)])) -> (box: CGRect, text: String) in
            // Merge all the texts within each group
            let text = group.texts.map({ $0.text }).joined(separator: " ")
            return (box: group.box, text: text)
        }

        return result
    }

    // Function to draw bounding boxes around the given observations in the given image
    private func drawBoundingBoxes(around observations: [VNRecognizedTextObservation], in image: CGImage) -> NSImage? {
        let imageSize = CGSize(width: image.width, height: image.height)

        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: image.bytesPerRow,
            space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(origin: .zero, size: imageSize))

        for observation in observations {
            let boundingBox = observation.boundingBox
            let rect = CGRect(x: boundingBox.origin.x * imageSize.width,
                              y: boundingBox.origin.y * imageSize.height,
                              width: boundingBox.width * imageSize.width,
                              height: boundingBox.height * imageSize.height)

            context.setStrokeColor(NSColor.red.cgColor)
            context.stroke(rect, width: 2)
        }

        guard let imageWithBoxes = context.makeImage() else { return NSImage() }
        return NSImage(cgImage: imageWithBoxes, size: imageSize)
    }

    func copyImageToClipboard(nsImage: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }
}

extension NSImage {
    func toCGImage() -> CGImage? {
        var rect = CGRect(origin: CGPoint.zero, size: self.size)
        return self.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
