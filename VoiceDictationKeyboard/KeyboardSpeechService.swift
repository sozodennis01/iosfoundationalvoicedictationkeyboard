//
//  KeyboardSpeechService.swift
//  VoiceDictationKeyboard
//
//  Created by Claude on 1/8/26.
//

import Foundation
import Combine
import Speech
import AVFoundation

@available(iOS 26.0, *)
@MainActor
class KeyboardSpeechService: ObservableObject {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var audioEngine: AVAudioEngine?
    private var currentTranscript = ""

    var hasPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioApplication.shared.recordPermission == .granted
    }

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechGranted else { return false }

        // Request microphone permission
        let micGranted = await AVAudioApplication.requestRecordPermission()

        return speechGranted && micGranted
    }

    func startRecording() async throws {
        // Reset state
        currentTranscript = ""

        // Create transcriber
        transcriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )

        guard let transcriber = transcriber else {
            throw NSError(domain: "KeyboardSpeechService", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create transcriber"])
        }

        // Create analyzer
        analyzer = SpeechAnalyzer(modules: [transcriber])

        // Create input stream
        let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputBuilder = builder

        // Start analyzer
        Task {
            try await analyzer?.start(inputSequence: inputSequence)
        }

        // Consume results
        Task {
            do {
                for try await result in transcriber.results {
                    self.currentTranscript = String(result.text.characters)
                }
            } catch {
                print("Transcription error: \(error)")
            }
        }

        // Set up audio engine
        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.inputBuilder?.yield(AnalyzerInput(buffer: buffer))
        }

        try engine.start()
    }

    func stopRecording() -> String {
        // Stop audio engine
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        // Finish input stream
        inputBuilder?.finish()
        inputBuilder = nil

        // Clean up analyzer and transcriber
        analyzer = nil
        transcriber = nil

        return currentTranscript
    }
}
