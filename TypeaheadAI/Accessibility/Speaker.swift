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
    private let speaker: AVSpeechSynthesizer = AVSpeechSynthesizer()

    func narrate(_ text: String) {
        if isNarrateEnabled {
            let utterance = AVSpeechUtterance(string: NSLocalizedString(text, comment: ""))
            utterance.prefersAssistiveTechnologySettings = true
            speaker.speak(utterance)
        }
    }

    func cancel() {
        speaker.stopSpeaking(at: .immediate)
    }
}
