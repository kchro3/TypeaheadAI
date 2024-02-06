//
//  StreamingSpeechProcessor.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 2/6/24.
//

import AVFoundation
import Foundation
import SwiftUI

class StreamingSpeechProcessor: NSObject, AVSpeechSynthesizerDelegate, CanSimulateControl {

    @AppStorage("isNarrateEnabled") var isNarrateEnabled: Bool = true
    @AppStorage("selectedVoice") private var selectedVoice: String?
    @AppStorage("speakingRate") private var speakingRate: Double?
    @AppStorage("speakingVolume") private var speakingVolume: Double?
    @AppStorage("speakingPitch") private var speakingPitch: Double?

    private var buffer: String = ""
    private let synthesizer = AVSpeechSynthesizer()
    private let delimiters: [String] = [". ", "! ", "? ", "\n"]

    var onFinish: (() -> Void)? = nil

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func processToken(_ token: String) {
        buffer.append(token)
        checkAndProcessBuffer()
    }

    private func checkAndProcessBuffer() {
        if let lastDelimiterIndex = findLastDelimiter() {
            let range = buffer.startIndex..<buffer.index(buffer.startIndex, offsetBy: lastDelimiterIndex)
            let textToRead = String(buffer[range])
            speak(text: textToRead)
            buffer.removeSubrange(range)
        }
    }

    private func findLastDelimiter() -> Int? {
        return delimiters.compactMap { delimiter -> Int? in
            guard let range = buffer.range(of: delimiter, options: .backwards) else {
                return nil
            }
            return buffer.distance(from: buffer.startIndex, to: range.lowerBound) + delimiter.count - 1
        }.max()
    }

    func speak(text: String, withCallback: Bool = false) {
        if isNarrateEnabled {
            Task {
                let utterance = AVSpeechUtterance(string: NSLocalizedString(text, comment: ""))

                if let selectedVoice = selectedVoice {
                    utterance.voice = AVSpeechSynthesisVoice(identifier: selectedVoice)
                }

                if let speakingRate = speakingRate {
                    utterance.rate = Float(speakingRate)
                }

                if let speakingVolume = speakingVolume {
                    utterance.volume = Float(speakingVolume)
                }

                if let pitch = speakingPitch {
                    utterance.pitchMultiplier = Float(pitch)
                }

                utterance.prefersAssistiveTechnologySettings = true

                if withCallback {
                    utterance.postUtteranceDelay = 1.0
                } else {
                    utterance.postUtteranceDelay = 0.0
                }

                if !synthesizer.isSpeaking {
                    try await simulateControl()
                }

                synthesizer.speak(utterance)
            }
        }
    }

    func flushBuffer(withCallback: Bool = false) {
        if !buffer.isEmpty {
            speak(text: buffer, withCallback: withCallback)
            buffer.removeAll()
        } else {
            speak(text: "", withCallback: withCallback)
        }
    }

    func cancel() {
        synthesizer.stopSpeaking(at: .immediate)
        buffer.removeAll()
    }

    // MARK: - AVSpeechSynthesizerDelegate methods

    /// NOTE: Hacky but useful way to ensure that the callback is executed after the speaker finishes talking.
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if utterance.postUtteranceDelay > 0.0 {
            onFinish?()
        }
    }
}
