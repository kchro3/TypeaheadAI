//
//  TranscriptionManager.swift
//  TypeaheadAI
//
//  Created by Jeff Hara on 9/17/23.
//

import Foundation
import AVFoundation
import Speech
import os.log

enum TranscriptionManagerError: Error {
    case notAuthorized
    case illegalState

    var localizedDescription: String {
        switch self {
        case .notAuthorized:
            return "The user has not authorized speech recognition"
        case .illegalState:
            return "Speech recognizer is not available"
        }
    }
}

class TranscriptionManager {
    private let logger = Logger(
        subsystem: "ai.typeahead.TypeaheadAI",
        category: "TranscriptionManager"
    )

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording(completion: @escaping (String) -> Void) {
        self.recognitionTask?.cancel()
        self.recognitionTask = nil

        requestSpeechAuthorization() { [weak self] result in
            switch result {
            case .success():
                do {
                    try self?.setupRecording(completion: completion)
                } catch {
                    self?.logger.error("\(error.localizedDescription)")
                }
            case .failure(let error):
                self?.logger.error("Authorization failed with error: \(error.localizedDescription)")
            }
        }
    }

    private func setupRecording(completion: @escaping (String) -> Void) throws {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        audioEngine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer()

        guard let inputNode = audioEngine?.inputNode else {
            self.logger.error("AudioEngine is not initialized")
            throw TranscriptionManagerError.illegalState
        }

        inputNode.reset()
        inputNode.removeTap(onBus: 0)

        // Get the system recording format
        let hardwareFormat = inputNode.inputFormat(forBus: 0)
        let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: hardwareFormat.sampleRate, channels: 1, interleaved: false)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine?.prepare()
        do {
            try audioEngine?.start()
        } catch {
            logger.error("Audio engine failed to start: \(error.localizedDescription)")
            throw TranscriptionManagerError.illegalState
        }

        DispatchQueue.main.async {
            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: self.recognitionRequest!) { [weak self] (result, error) in
                guard let self = self else { return }

                if let error = error as NSError?, error.domain == "kAFAssistantErrorDomain" && error.code == 216 {
                    self.logger.info("Recognition task was cancelled")
                } else if let error = error {
                    self.logger.error("Recognition task failed with error: \(error.localizedDescription)")
                } else if let transcription = result?.bestTranscription {
                    self.logger.info("Recognized text: \(transcription.formattedString)")
                    completion(transcription.formattedString)
                } else {
                    self.logger.info("No recognition result available")
                }
            }
        }

        logger.info("Successfully started recording")
    }

    /// When using Bluetooth headphones, the output audio quality drops if the microphone is enabled.
    /// That can't be helped, but make sure to test with BT headphones that when the recording stops
    /// the audio quality returns to normal. Could be a sign that something wasn't cleaned up properly.
    func stopRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine?.stop()
        audioEngine?.inputNode.reset()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        speechRecognizer = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
    }

    private func requestSpeechAuthorization(completion: @escaping (Result<Void, TranscriptionManagerError>) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self?.speechRecognizer = SFSpeechRecognizer()
                    if self?.speechRecognizer?.isAvailable ?? false {
                        completion(.success(()))
                    } else {
                        self?.logger.error("\(TranscriptionManagerError.illegalState.localizedDescription)")
                        completion(.failure(.illegalState))
                    }
                default:
                    self?.logger.error("\(TranscriptionManagerError.notAuthorized.localizedDescription)")
                    completion(.failure(.notAuthorized))
                }
            }
        }
    }
}
