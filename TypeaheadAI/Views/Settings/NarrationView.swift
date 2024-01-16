//
//  NarrationView.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 1/15/24.
//

import AVFoundation
import SwiftUI

struct NarrationView: View {
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("selectedLanguage") private var selectedLanguage: String = ""
    @AppStorage("selectedVoice") private var selectedVoice: String = ""
    @AppStorage("speakingRate") private var speakingRate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("speakingVolume") private var speakingVolume: Double = 1.0
    @AppStorage("speakingPitch") private var speakingPitch: Double = 1.0

    let languages: [String]
    var speechVoices: [String : [String]]

    init() {
        languages = Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language }).sorted()

        speechVoices = [:]
        for speechVoice in AVSpeechSynthesisVoice.speechVoices().sorted(by: { a, b in
            a.name < b.name
        }) {
            var speechVoiceByLanguage = speechVoices[speechVoice.language] ?? []
            speechVoiceByLanguage.append(speechVoice.identifier)
            speechVoices[speechVoice.language] = speechVoiceByLanguage
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Narration").font(.title)

            List {
                Picker("System speech language", selection: $selectedLanguage) {
                    ForEach(languages, id: \.self) { languageCode in
                        if let language = Locale.current.localizedString(forLanguageCode: languageCode) {
                            Text("\(language) (\(languageCode))").tag(languageCode)
                        } else {
                            Text(languageCode).tag(languageCode)
                        }
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedLanguage) { newLanguage in
                    if let voicesForLanguage = speechVoices[newLanguage], !voicesForLanguage.isEmpty {
                        selectedVoice = voicesForLanguage.first!
                    }
                }
                .padding(5)

                Picker("System voice", selection: $selectedVoice) {
                    ForEach(speechVoices[selectedLanguage] ?? [], id: \.self) {
                        if let voice = AVSpeechSynthesisVoice(identifier: $0) {
                            switch voice.quality {
                            case .default:
                                Text(voice.name).tag($0)
                            case .enhanced:
                                Text("\(voice.name) (Enhanced)").tag($0)
                            case .premium:
                                Text("\(voice.name) (Premium)").tag($0)
                            }
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(5)

                Slider(value: $speakingRate, in: Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate), label: {
                    Text("Speaking rate")
                        .frame(width: 200, alignment: .leading)
                }) {
                    Image(systemName: "tortoise.fill")
                } maximumValueLabel: {
                    Image(systemName: "hare.fill")
                }
                .padding(5)

                Slider(value: $speakingVolume, label: {
                    Text("Speaking volume")
                        .frame(width: 200, alignment: .leading)
                }) {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(5)

                Slider(value: $speakingPitch, in: 0.5...2.0, label: {
                    Text("Pitch Multiplier")
                        .frame(width: 200, alignment: .leading)
                }) {
                    Image(systemName: "speaker.fill")
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                }
                .padding(5)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .onAppear {
            // Initialize with the default voice when the view appears
            selectedLanguage = Locale.preferredLanguages.first!
            if let defaultVoice = AVSpeechSynthesisVoice(language: selectedLanguage) {
                selectedVoice = defaultVoice.identifier
            }
        }
    }
}

#Preview {
    NarrationView()
}
