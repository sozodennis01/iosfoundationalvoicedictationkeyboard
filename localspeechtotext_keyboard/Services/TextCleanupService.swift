import Foundation
import FoundationModels
import Combine

@available(iOS 26.0, *)
class TextCleanupService: ObservableObject {
    private var session: LanguageModelSession?

    @Published var isProcessing = false
    @Published var isModelAvailable = false

    init() {
        checkModelAvailability()
    }

    // MARK: - Model Availability

    func checkModelAvailability() {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            isModelAvailable = true
            // Initialize session only when model is available
            session = LanguageModelSession()
        case .unavailable(.deviceNotEligible):
            isModelAvailable = false
        case .unavailable(.appleIntelligenceNotEnabled):
            isModelAvailable = false
        case .unavailable(.modelNotReady):
            isModelAvailable = false
        case .unavailable:
            isModelAvailable = false
        @unknown default:
            isModelAvailable = false
        }
    }

    // MARK: - Text Cleanup

    func cleanupText(_ rawText: String) async throws -> String {
        guard !rawText.isEmpty else {
            return rawText
        }

        // Check availability before processing
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw TextCleanupError.deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            throw TextCleanupError.appleIntelligenceDisabled
        case .unavailable(.modelNotReady):
            throw TextCleanupError.modelNotReady
        case .unavailable:
            throw TextCleanupError.modelUnavailable
        @unknown default:
            throw TextCleanupError.modelUnavailable
        }

        isProcessing = true
        defer { isProcessing = false }

        let prompt = createCleanupPrompt(rawText: rawText)

        // Create session if not already created
        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            throw TextCleanupError.sessionNotInitialized
        }

        do {
            //TODO add safety here where if the model is processing something, wait for it?
            let response = try await session.respond(to: prompt)
            return extractCleanedText(from: response.content)
        } catch {
            throw TextCleanupError.processingFailed(error.localizedDescription)
        }
    }

    // MARK: - Prompt Creation

    func createCleanupPrompt(rawText: String) -> String {
        return """
        You are a text cleanup assistant. Your task is to transform a voice-to-text transcript into clear, well-formatted written text while preserving the speaker’s original meaning.

        Instructions:
            •    Fix punctuation, capitalization, and obvious transcription errors
            •    Remove filler words (um, uh, like, you know, etc.)
            •    Remove false starts, repetitions, and stutters
            •    Keep the meaning, tone, and intent the same (do not add new info)
            •    Preserve important details (names, numbers, dates, commitments)
            •    If the speaker is clearly drafting a specific format, output in that format:
            •    Email (with subject + greeting + paragraphs + sign-off)
            •    Bullets/checklists for lists
            •    Headings for sections
            •    Short paragraphs for narrative
            •    Do not include any commentary, labels, or extra text

        Raw transcript:
        \(rawText)

        Cleaned text:
        """
    }

    // MARK: - Response Parsing

    private func extractCleanedText(from response: String) -> String {
        // Extract the cleaned text from the response
        // The session.respond(to:) returns a String directly
        return response.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum TextCleanupError: LocalizedError {
    case sessionNotInitialized
    case processingFailed(String)
    case emptyResponse
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .sessionNotInitialized:
            return "Language model session not initialized"
        case .processingFailed(let details):
            return "Text cleanup failed: \(details)"
        case .emptyResponse:
            return "Received empty response from language model"
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence"
        case .appleIntelligenceDisabled:
            return "Please enable Apple Intelligence in Settings"
        case .modelNotReady:
            return "Language model is still loading, please try again"
        case .modelUnavailable:
            return "Language model is unavailable"
        }
    }
}
