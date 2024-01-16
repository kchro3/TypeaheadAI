//
//  Speaker.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/13/24.
//

import AVFoundation
import Foundation
import SwiftUI

class Speaker {
    @AppStorage("isNarrateEnabled") var isNarrateEnabled: Bool = false
    @AppStorage("selectedVoice") private var selectedVoice: String?
    @AppStorage("speakingRate") private var speakingRate: Double?
    @AppStorage("speakingVolume") private var speakingVolume: Double?
    @AppStorage("speakingPitch") private var speakingPitch: Double?

    private let speaker: AVSpeechSynthesizer = AVSpeechSynthesizer()

    func narrate(_ text: String) {
        if isNarrateEnabled {
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

            speaker.speak(utterance)
        }
    }

    func cancel() {
        speaker.stopSpeaking(at: .immediate)
    }
}
