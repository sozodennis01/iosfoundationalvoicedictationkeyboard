import Foundation
import FoundationModels

@available(iOS 26.0, *)
class TextCleanupService: ObservableObject {
    private var session: LanguageModelSession?

    @Published var isProcessing = false

    init() {
        // Initialize the language model session
        session = LanguageModelSession()
    }

    // MARK: - Text Cleanup

    func cleanupText(_ rawText: String) async throws -> String {
        guard !rawText.isEmpty else {
            return rawText
        }

        isProcessing = true
        defer { isProcessing = false }

        let prompt = createCleanupPrompt(rawText: rawText)

        guard let session = session else {
            throw TextCleanupError.sessionNotInitialized
        }

        do {
            let response = try await session.respond(to: prompt)
            return extractCleanedText(from: response)
        } catch {
            throw TextCleanupError.processingFailed(error.localizedDescription)
        }
    }

    // MARK: - Prompt Creation

    func createCleanupPrompt(rawText: String) -> String {
        return """
        You are a text cleanup assistant. Your task is to clean up the following voice-to-text transcript.

        Instructions:
        - Fix punctuation and capitalization
        - Remove filler words (um, uh, like, you know, etc.)
        - Remove false starts and repetitions
        - Preserve the original meaning exactly
        - Output ONLY the cleaned text, no explanations or formatting

        Raw transcript:
        \(rawText)

        Cleaned text:
        """
    }

    // MARK: - Response Parsing

    private func extractCleanedText(from response: LanguageModelSessionResponse) -> String {
        // Extract the cleaned text from the response
        // The response.content should contain the cleaned text
        // This is a simplified version - adjust based on actual API response structure
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum TextCleanupError: LocalizedError {
    case sessionNotInitialized
    case processingFailed(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .sessionNotInitialized:
            return "Language model session not initialized"
        case .processingFailed(let details):
            return "Text cleanup failed: \(details)"
        case .emptyResponse:
            return "Received empty response from language model"
        }
    }
}
