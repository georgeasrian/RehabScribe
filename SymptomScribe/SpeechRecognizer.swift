//
//  SpeechRecognizer.swift
//  SymptomScribe
//
//  Created by Aashni Shah on 10/1/24.
//

import Foundation
import Speech
import AVFoundation

class SpeechRecognizer: ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    @Published var transcript = ""

    init() {
        // Prepare the audio session and recognition request
        prepare()
    }

    private func prepare() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Speech recognition authorized")
                default:
                    print("Speech recognition authorization failed: \(authStatus.rawValue)")
                    // Handle authorization failure
                }
            }
        }

        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Microphone access granted")
                } else {
                    print("Microphone access denied")
                    // Handle microphone access denial
                }
            }
        }
    }

    func transcribe(completion: @escaping (Bool) -> Void) {
        do {
            try startTranscribing()
            completion(true)
        } catch {
            print("Error starting transcription: \(error.localizedDescription)")
            completion(false)
        }
    }

    private func startTranscribing() throws {
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

//         Commented out preferred input
         if let availableInputs = audioSession.availableInputs {
             for input in availableInputs {
                 if input.portType == .bluetoothHFP {
                     try audioSession.setPreferredInput(input)
                     break
                 }
             }
         }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create recognition request")
        }
        recognitionRequest.shouldReportPartialResults = true

         if speechRecognizer?.supportsOnDeviceRecognition ?? false {
             recognitionRequest.requiresOnDeviceRecognition = true
         }

        let inputNode = audioEngine.inputNode

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let error = error {
                print("Recognition error: \(error.localizedDescription)")
                print("Error details: \(error)")
                self.stopTranscribing()
                return
            }

            if let result = result {
                DispatchQueue.main.async {
                    self.transcript = result.bestTranscription.formattedString
                    print("Transcribed Text: \(self.transcript)")
                }
            }

            if result?.isFinal == true {
                self.stopTranscribing()
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        print("Audio engine started")
    }

    func stopTranscribing() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        print("Audio engine stopped")
    }
}
