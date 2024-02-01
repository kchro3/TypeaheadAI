//
//  Speaker.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/13/24.
//

import AVFoundation
import Carbon.HIToolbox
import Foundation
import SwiftUI

class Speaker: NSObject, AVSpeechSynthesizerDelegate, CanSimulateControl {
    @AppStorage("isNarrateEnabled") var isNarrateEnabled: Bool = true
    @AppStorage("selectedVoice") private var selectedVoice: String?
    @AppStorage("speakingRate") private var speakingRate: Double?
    @AppStorage("speakingVolume") private var speakingVolume: Double?
    @AppStorage("speakingPitch") private var speakingPitch: Double?

    private let speaker: AVSpeechSynthesizer = AVSpeechSynthesizer()
    var onFinish: (() -> Void)? = nil

    override init() {
        super.init()
        speaker.delegate = self
    }

    func speak(_ text: String, withCallback: Bool = false) {
        if isNarrateEnabled {
            Task {
                let utterance = AVSpeechUtterance(string: text)

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

                if !speaker.isSpeaking {
                    try await simulateControl()
                }

                speaker.speak(utterance)
            }
        }
    }

    func cancel() {
        speaker.stopSpeaking(at: .immediate)
    }

    // MARK: - AVSpeechSynthesizerDelegate methods

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if utterance.postUtteranceDelay > 0.0 {
            onFinish?()
        }
    }
}
