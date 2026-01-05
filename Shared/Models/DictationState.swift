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
}
