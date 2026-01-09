import Foundation

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

    init(rawText: String = "", cleanedText: String = "", status: DictationStatus = .idle, timestamp: Date = Date()) {
        self.rawText = rawText
        self.cleanedText = cleanedText
        self.status = status
        self.timestamp = timestamp
    }
}
