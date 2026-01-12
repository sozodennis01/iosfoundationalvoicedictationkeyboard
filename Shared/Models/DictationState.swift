import Foundation

// MARK: - Command Protocol

enum DictationCommand: String, Codable {
    case armMic           // Keyboard → Host: prepare mic session
    case micReady         // Host → Keyboard: ready to record
    case startRecording   // Keyboard → Host: begin capture
    case stopRecording    // Keyboard → Host: end capture
    case processing       // Host → Keyboard: cleaning text
    case textReady        // Host → Keyboard: text available
    case error            // Host → Keyboard: something failed
}

struct DictationSession: Codable {
    let sessionId: UUID
    var command: DictationCommand
    var timestamp: Date
    var error: String?

    init(sessionId: UUID = UUID(), command: DictationCommand, timestamp: Date = Date(), error: String? = nil) {
        self.sessionId = sessionId
        self.command = command
        self.timestamp = timestamp
        self.error = error
    }
}

// MARK: - Legacy Status (for backward compatibility)

enum DictationStatus: String, Codable {
    case idle
    case recording
    case processing
    case ready
    case error
}

struct DictationState: Codable {
    var rawText: String
    var cleanedText: String
    var status: DictationStatus
    var timestamp: Date
    var session: DictationSession?
    var rawTranscript: String?

    init(rawText: String = "", cleanedText: String = "", status: DictationStatus = .idle, timestamp: Date = Date(), session: DictationSession? = nil, rawTranscript: String? = nil) {
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.status = status
        self.timestamp = timestamp
        self.session = session
        self.rawTranscript = rawTranscript
    }
}
