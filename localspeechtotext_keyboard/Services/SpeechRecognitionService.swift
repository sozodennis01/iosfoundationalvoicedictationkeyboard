import Foundation
import Speech
import AVFoundation
import Combine
import os

@available(iOS 26.0, *)
class SpeechRecognitionService: ObservableObject {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "localspeechtotext_keyboard", category: "SpeechRecognitionService")
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var currentTranscript = ""

    init() {
        checkPermissions()
        // Note: Don't setup audio engine here - we'll do it in initializeAudioSession()
    }

    // MARK: - Audio Engine Management

    /// Initializes the audio session and starts the audio engine (no tap installed)
    func initializeAudioSession() async throws {
        // If already running, nothing to do
        if let engine = audioEngine, engine.isRunning {
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetoothHFP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create and start engine without any tap
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        guard format.channelCount > 0 else {
            logger.error("AudioSession init failed: input format has 0 channels")
            throw SpeechRecognitionError.audioEngineError
        }

        engine.prepare()
        do {
            try engine.start()
            logger.debug("AudioSession initialized and engine started (warm, no tap)")
        } catch {
            logger.error("AudioSession init failed to start engine: \(error.localizedDescription, privacy: .public)")
            throw SpeechRecognitionError.audioEngineError
        }

        audioEngine = engine
    }

    // MARK: - Permission Management

    func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        hasPermission = speechStatus == .authorized
    }

    func requestPermissions() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        await MainActor.run {
            hasPermission = granted
        }
        return granted
    }

    func requestMicrophonePermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    // MARK: - Recording (Phase 1) - Records audio to file

    func startRecording() async throws {
        guard hasPermission else {
            logger.error("startRecording aborted: permissionDenied")
            throw SpeechRecognitionError.permissionDenied
        }

        // Ensure session + engine are ready
        try await initializeAudioSession()
        guard let engine = audioEngine else {
            throw SpeechRecognitionError.audioEngineError
        }

        let inputNode = engine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        guard recordingFormat.channelCount > 0 else {
            throw SpeechRecognitionError.audioEngineError
        }

        // If engine was stopped (e.g., after prior stop), restart before tapping
        if !engine.isRunning {
            do {
                try engine.start()
                logger.debug("Engine was stopped; restarted before installing tap")
            } catch {
                logger.error("Engine restart failed before tap: \(error.localizedDescription, privacy: .public)")
                throw SpeechRecognitionError.audioEngineError
            }
        }

        // Create temporary file for audio recording
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("recording_temp_\(UUID().uuidString).caf")
        recordingURL = tempURL

        audioFile = try AVAudioFile(
            forWriting: tempURL,
            settings: recordingFormat.settings,
            commonFormat: recordingFormat.commonFormat,
            interleaved: false
        )
        logger.debug("Recording file created at \(tempURL.path, privacy: .public)")

        // Install tap (engine may already be running)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.writeAudioBufferToFile(buffer)
        }
        logger.debug("Tap installed on inputNode; recording started")

        await MainActor.run {
            isRecording = true
            currentTranscript = ""
        }
    }

    private func writeAudioBufferToFile(_ buffer: AVAudioPCMBuffer) {
        do {
            try audioFile?.write(from: buffer)
        } catch {
            print("Error writing audio buffer to file: \(error)")
        }
    }

    // MARK: - Transcription (Phase 2) - Transcribes recorded file

    func stopRecordingAndTranscribe() async throws -> String {
        guard let recordingURL = recordingURL else {
            throw SpeechRecognitionError.recognitionFailed
        }

        // Tear down tap and close the file
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            do {
                try engine.start() // keep engine warm after stop
                logger.debug("Engine restarted warm after stop")
            } catch {
                logger.error("Engine restart failed after stop: \(error.localizedDescription, privacy: .public)")
                audioEngine = nil
            }
        }
        try? audioFile?.close()

        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            throw SpeechRecognitionError.recognitionFailed
        }

        let transcriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        await MainActor.run {
            isRecording = false
        }

        var transcriptParts: [String] = []

        do {
            let audioFile = try AVAudioFile(forReading: recordingURL)
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }

            for try await result in transcriber.results {
                let text = String(result.text.characters)
                transcriptParts.append(text)
            }
        } catch {
            await analyzer.cancelAndFinishNow()
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw SpeechRecognitionError.recognitionFailed
        }

        // Clean up temporary file
        try? FileManager.default.removeItem(at: recordingURL)

        let finalTranscript = transcriptParts.joined()
        await MainActor.run {
            currentTranscript = finalTranscript
        }

        audioFile = nil
        self.recordingURL = nil

        return finalTranscript
    }

    // MARK: - Cancel recording without transcription

    func cancelRecording() {
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            do {
                try engine.start() // keep warm
                logger.debug("Engine restarted warm after cancel")
            } catch {
                logger.error("Engine restart failed after cancel: \(error.localizedDescription, privacy: .public)")
                audioEngine = nil
            }
        }

        try? audioFile?.close()

        if let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        audioFile = nil
        recordingURL = nil
        isRecording = false
        currentTranscript = ""
    }

// MARK: - Errors

enum SpeechRecognitionError: LocalizedError {
    case permissionDenied
    case recognitionFailed
    case audioEngineError

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission is required"
        case .recognitionFailed:
            return "Failed to recognize speech"
        case .audioEngineError:
            return "Audio engine encountered an error"
        }
    }
}
}
