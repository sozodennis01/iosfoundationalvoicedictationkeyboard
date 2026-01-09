import Foundation
import Speech
import AVFoundation
import Combine

@available(iOS 26.0, *)
class SpeechRecognitionService: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingURL: URL?

    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var currentTranscript = ""

    init() {
        checkPermissions()
        setupAudioEngine()
    }

    // MARK: - Audio Engine Management

    private func setupAudioEngine() {
        guard audioEngine == nil else { return }
        audioEngine = AVAudioEngine()
        // Note: Don't prepare the engine here - prepare only when starting recording
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
            throw SpeechRecognitionError.permissionDenied
        }

        // Configure audio session for background recording with mixing
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create temporary file for audio recording
        let tempDir = FileManager.default.temporaryDirectory
        recordingURL = tempDir.appendingPathComponent("recording_temp_\(UUID().uuidString).caf")

        // Set up audio engine (don't prepare yet)
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }
        guard let audioEngine = audioEngine else {
            throw SpeechRecognitionError.audioEngineError
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        await MainActor.run {
            isRecording = true
            currentTranscript = ""
        }

        // Create audio file for writing
        audioFile = try AVAudioFile(
            forWriting: recordingURL!,
            settings: recordingFormat.settings,
            commonFormat: recordingFormat.commonFormat,
            interleaved: false
        )

        // Install tap to write audio to file (not to analyzer)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            self.writeAudioBufferToFile(buffer)
        }

        // Prepare the engine after installing the tap
        audioEngine.prepare()

        // Start audio engine
        try audioEngine.start()
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

        // Stop audio engine and close file
        audioEngine?.inputNode.removeTap(onBus: 0)
        try? audioFile?.close()
        audioEngine?.stop()
        audioEngine?.prepare() // Keep prepared for next recording

        guard FileManager.default.fileExists(atPath: recordingURL.path) else {
            throw SpeechRecognitionError.recognitionFailed
        }

        let transcriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [], // No volatile results needed for file transcription
            attributeOptions: []
        )

        let analyzer = SpeechAnalyzer(modules: [transcriber])

        await MainActor.run {
            isRecording = false
        }

        // Transcribe the recorded file
        var transcriptParts: [String] = []

        do {
            // Create AVAudioFile from the recorded URL for analysis
            let audioFile = try AVAudioFile(forReading: recordingURL)
            // Use the file-based transcription pattern from the quickstart guide
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }

            // Collect all transcription results
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                transcriptParts.append(text)
            }
        } catch {
            // If file analysis fails, try canceling properly
            await analyzer.cancelAndFinishNow()
            throw SpeechRecognitionError.recognitionFailed
        }

        // Clean up temporary file
        try? FileManager.default.removeItem(at: recordingURL)

        let finalTranscript = transcriptParts.joined()
        await MainActor.run {
            currentTranscript = finalTranscript
        }

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        return finalTranscript
    }

    // MARK: - Cancel recording without transcription

    func cancelRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.prepare()

        // Clean up temporary file if it exists
        if let recordingURL = recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }

        audioFile = nil
        recordingURL = nil
        isRecording = false
        currentTranscript = ""

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
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
