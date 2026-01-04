import Foundation
import Speech

@available(iOS 26.0, *)
class SpeechRecognitionService: ObservableObject {
    private var transcriber: SpeechTranscriber?
    private let locale = Locale(identifier: "en_US")

    @Published var isRecording = false
    @Published var hasPermission = false

    init() {
        checkPermissions()
    }

    // MARK: - Permission Management

    func checkPermissions() {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        hasPermission = speechStatus == .authorized
    }

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let status = await SFSpeechRecognizer.requestAuthorization()

        await MainActor.run {
            hasPermission = status == .authorized
        }

        return status == .authorized
    }

    // MARK: - Transcription

    func startTranscription() async throws -> AsyncStream<String> {
        guard hasPermission else {
            throw SpeechRecognitionError.permissionDenied
        }

        transcriber = SpeechTranscriber(locale: locale)
        isRecording = true

        return AsyncStream { continuation in
            Task {
                do {
                    guard let transcriber = self.transcriber else {
                        continuation.finish()
                        return
                    }

                    // Note: This is a placeholder for the actual SpeechTranscriber API
                    // The real implementation will use the audio input source
                    // For now, this shows the expected structure

                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    func stopTranscription() {
        transcriber = nil
        isRecording = false
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
