//
//  SpecialCutActor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/8/23.
//

import Foundation
import SwiftUI
import Carbon.HIToolbox

import AppKit
import Cocoa
import Vision
import os.log

struct ImageCaptionPayload: Codable {
    let caption: String
}

/// This polls the clipboard to see if anything new has been added to the clipboard.
class LegacyClipboardMonitor {
    private var timer: Timer?
    private var pasteboardChangeCount: Int
    var onScreenshotDetected: (() -> Void)?
    private let mouseEventMonitor: MouseEventMonitor

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "LegacyClipboardMonitor"
    )

    init(mouseEventMonitor: MouseEventMonitor) {
        self.mouseEventMonitor = mouseEventMonitor
        self.pasteboardChangeCount = NSPasteboard.general.changeCount
    }

    func startMonitoring() {
        logger.debug("start monitoring")
        // TODO: Maybe this should be a separate variable? Could introduce race conditions
        self.mouseEventMonitor.mouseClicked = false
        timer = Timer(timeInterval: 0.5, target: self, selector: #selector(timerFired), userInfo: nil, repeats: true)
        RunLoop.main.add(timer!, forMode: .default)  // Needed to kick off the timer
    }

    @objc private func timerFired() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != self.pasteboardChangeCount {
            self.pasteboardChangeCount = currentChangeCount

            if NSPasteboard.general.data(forType: .tiff) != nil {
                logger.debug("Screenshot detected on clipboard")
                onScreenshotDetected?()
                self.stopMonitoring()
            }
        }

        if mouseEventMonitor.mouseClicked {
            logger.debug("Click detected. Exiting...")
            self.stopMonitoring()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}

actor SpecialCutActor {
    private let clipboardMonitor: LegacyClipboardMonitor
    private let promptManager: QuickActionManager
    private let clientManager: ClientManager
    private let modalManager: ModalManager
    private let appContextManager: AppContextManager

    @AppStorage("numSmartCuts") var numSmartCuts: Int?
    @AppStorage("bio") var bio: String?

    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "SpecialCutActor"
    )

    private struct Constants {
        static let thresholdX: CGFloat = 0.01
        static let thresholdY: CGFloat = 0.02
    }

    init(mouseEventMonitor: MouseEventMonitor,
         promptManager: QuickActionManager,
         clientManager: ClientManager,
         modalManager: ModalManager,
         appContextManager: AppContextManager
    ) {
        self.clipboardMonitor = LegacyClipboardMonitor(mouseEventMonitor: mouseEventMonitor)
        self.promptManager = promptManager
        self.clientManager = clientManager
        self.modalManager = modalManager
        self.appContextManager = appContextManager
    }

    func specialCut() async throws {
        let appInfo = try await self.appContextManager.getActiveAppInfo()

        do {
            self.clipboardMonitor.stopMonitoring()
            try self.simulateScreengrab() {
                guard let tiffData = NSPasteboard.general.data(forType: .tiff),
                      let image = NSImage(data: tiffData),
                      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                    self.logger.error("Failed to retrieve image from clipboard")
                    return
                }

                self.performOCR(image: cgImage) { recognizedText, _ in
                    self.logger.info("OCRed text: \(recognizedText)")

                    Task {
                        try await self.modalManager.forceRefresh()
                        await self.modalManager.showModal()
                        await NSApp.activate(ignoringOtherApps: true)

                        if let activePrompt = self.clientManager.getActivePrompt() {
                            await self.modalManager.setUserMessage("\(activePrompt)\n:\(recognizedText)", appContext: appInfo.appContext)
                        } else {
                            await self.modalManager.setUserMessage("OCR'ed text:\n\(recognizedText)", appContext: appInfo.appContext)
                        }

                        if let nCuts = self.numSmartCuts {
                            self.numSmartCuts = nCuts + 1
                        } else {
                            self.numSmartCuts = 1
                        }

                        do {
                            if let intents = try await self.clientManager.suggestIntents(
                                id: UUID(),
                                username: NSUserName(),
                                userFullName: NSFullUserName(),
                                userObjective: self.promptManager.getActivePrompt(),
                                userBio: self.bio ?? "",
                                userLang: Locale.preferredLanguages.first ?? "",
                                copiedText: recognizedText,
                                messages: self.modalManager.messages,
                                history: [],
                                appContext: appInfo.appContext,
                                incognitoMode: !self.modalManager.online
                            ), !intents.intents.isEmpty {
                                await self.modalManager.setUserIntents(intents: intents.intents)
                            } else {
                                try await self.modalManager.replyToUserMessage()
                            }
                        } catch {
                            self.logger.error("\(error.localizedDescription)")
                            await self.modalManager.setError(error.localizedDescription, appContext: appInfo.appContext)
                        }
                    }
                }
            }
        } catch {
            self.logger.error("Failed to execute special cut: \(error)")
        }
    }

    private func simulateScreengrab(completion: @escaping () -> Void) throws {
        clipboardMonitor.onScreenshotDetected = {
            completion()
        }
        clipboardMonitor.startMonitoring()

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw CustomError.eventSourceCreationFailed
        }

        let down = CGEvent(keyboardEventSource: source, virtualKey: 0x56, keyDown: true)!
        down.flags = [.maskCommand, .maskControl, .maskShift]
        let up = CGEvent(keyboardEventSource: source, virtualKey: 0x56, keyDown: false)!
        up.flags = [.maskCommand, .maskControl, .maskShift]

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    enum CustomError: Error {
        case eventSourceCreationFailed
    }

    // Function to perform OCR on given image
    func performOCR(image: CGImage, completion: @escaping (String, NSImage?) -> Void) {
        let request = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            let groupedBoxesAndTexts = self.groupBoundingBoxes(observations)
            let allRecognizedText = groupedBoxesAndTexts.map { $0.text }.joined(separator: "\n")
            let imageWithBoxes = self.drawBoundingBoxes(around: observations, in: image)

            completion(allRecognizedText, imageWithBoxes)
        }

        request.recognitionLevel = .accurate
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            self.logger.info("performing OCR")
            try handler.perform([request])
        } catch {
            self.logger.error("OCR failed: \(error)")
        }
    }

    // Function to group recognized text bounding boxes based on overlaps
    func groupBoundingBoxes(_ observations: [VNRecognizedTextObservation]) -> [(box: CGRect, text: String)] {
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
    func drawBoundingBoxes(around observations: [VNRecognizedTextObservation], in image: CGImage) -> NSImage? {
        let imageSize = CGSize(width: image.width, height: image.height)

        guard let context = CGContext(data: nil,
                                      width: image.width,
                                      height: image.height,
                                      bitsPerComponent: image.bitsPerComponent,
                                      bytesPerRow: image.bytesPerRow,
                                      space: image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: image.bitmapInfo.rawValue) else {
            self.logger.error("Could not create context")
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
