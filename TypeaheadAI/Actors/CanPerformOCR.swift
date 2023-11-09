//
//  CanPerformOCR.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 11/9/23.
//

import Cocoa
import Foundation
import Vision

struct OCRConstants {
    static let thresholdX: CGFloat = 0.01
    static let thresholdY: CGFloat = 0.02
}

protocol CanPerformOCR {
    func performOCR(image: CGImage, completion: @escaping (String, NSImage?) -> Void)
}

extension CanPerformOCR {
    func performOCR(image: CGImage, completion: @escaping (String, NSImage?) -> Void) {
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let groupedBoxesAndTexts = self.groupBoundingBoxes(observations)
            let allRecognizedText = groupedBoxesAndTexts.map { $0.text }.joined(separator: "\n")
            let imageWithBoxes = self.drawBoundingBoxes(around: observations, in: image)

            completion(allRecognizedText, imageWithBoxes)
        }

        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCR failed: \(error)")
        }
    }

    // Function to group recognized text bounding boxes based on overlaps
    func groupBoundingBoxes(_ observations: [VNRecognizedTextObservation]) -> [(box: CGRect, text: String)] {
        let boxesAndTexts = observations.map {
            (box: $0.boundingBox.insetBy(dx: -OCRConstants.thresholdX, dy: -OCRConstants.thresholdY),
             text: $0.topCandidates(1).first?.string ?? "")
        }

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
    func drawBoundingBoxes(around observations: [VNRecognizedTextObservation], in image: CGImage) -> NSImage? {
        let imageSize = CGSize(width: image.width, height: image.height)

        guard let context = CGContext(data: nil,
                                      width: image.width,
                                      height: image.height,
                                      bitsPerComponent: 8, // image.bitsPerComponent,
                                      bytesPerRow: 0, // image.bytesPerRow,
                                      space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: image.bitmapInfo.rawValue) else {
            print("Could not create context")
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
}
