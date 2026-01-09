import Foundation
import Speech
import AVFoundation
import Combine

@available(iOS 26.0, *)
class SpeechRecognitionService: ObservableObject {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var audioEngine: AVAudioEngine?
    private var transcriptionTask: Task<Void, Never>?
    private var analyzerTask: Task<Void, Error>?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?

    @Published var isRecording = false
    @Published var hasPermission = false
    @Published var currentTranscript = ""

    init() {
        checkPermissions()
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

    // MARK: - Transcription

    func startTranscription() async throws -> AsyncStream<String> {
        guard hasPermission else {
            throw SpeechRecognitionError.permissionDenied
        }

        // Configure audio session for background recording with mixing
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.mixWithOthers, .defaultToSpeaker]
        )
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create transcriber with default locale for volatile (real-time) results
        let newTranscriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        transcriber = newTranscriber

        // Create analyzer with transcriber module
        let newAnalyzer = SpeechAnalyzer(modules: [newTranscriber])
        analyzer = newAnalyzer

        // Get the best audio format for the analyzer
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [newTranscriber])

        // Create async stream for feeding audio to analyzer
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = inputBuilder

        // Set up audio engine for microphone input
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw SpeechRecognitionError.audioEngineError
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        await MainActor.run {
            isRecording = true
            currentTranscript = ""
        }

        // Start the analyzer with the input sequence
        analyzerTask = Task {
            try await newAnalyzer.start(inputSequence: inputSequence)
        }

        return AsyncStream { continuation in
            // Start consuming transcription results
            self.transcriptionTask = Task {
                do {
                    for try await result in newTranscriber.results {
                        let text = String(result.text.characters)
                        await MainActor.run {
                            self.currentTranscript += text
                        }
                        continuation.yield(text)
                    }
                } catch {
                    // Handle transcription error
                }
                continuation.finish()
            }

            // Install tap to capture audio and feed to analyzer
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, time in
                guard let self = self else { return }
                self.processAudioBuffer(buffer)
            }

            // Start audio engine
            do {
                try audioEngine.start()
            } catch {
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                Task { @MainActor in
                    self.stopTranscription()
                }
            }
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let inputContinuation = inputContinuation else { return }

        // Convert buffer to analyzer format if needed
        if let analyzerFormat = analyzerFormat,
           let convertedBuffer = convertBuffer(buffer, to: analyzerFormat) {
            inputContinuation.yield(AnalyzerInput(buffer: convertedBuffer))
        } else {
            // Use original buffer if conversion not needed or fails
            inputContinuation.yield(AnalyzerInput(buffer: buffer))
        }
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format != format else {
            return buffer
        }

        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }

        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate
        )

        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if error != nil {
            return nil
        }

        return convertedBuffer
    }

    func stopTranscription() {
        // Finish the input stream
        inputContinuation?.finish()
        inputContinuation = nil

        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        // Cancel tasks
        analyzerTask?.cancel()
        analyzerTask = nil
        transcriptionTask?.cancel()
        transcriptionTask = nil

        transcriber = nil
        analyzer = nil
        analyzerFormat = nil
        isRecording = false
        
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
