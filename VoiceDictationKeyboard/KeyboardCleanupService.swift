//
//  KeyboardCleanupService.swift
//  VoiceDictationKeyboard
//
//  Created by Claude on 1/8/26.
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
@MainActor
class KeyboardCleanupService: ObservableObject {
    enum CleanupError: LocalizedError {
        case modelUnavailable
        case cleanupFailed

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Apple Intelligence is not available on this device"
            case .cleanupFailed:
                return "Text cleanup failed"
            }
        }
    }

    func cleanupText(_ rawText: String) async throws -> String {
        guard !rawText.isEmpty else {
            return rawText
        }

        // Check model availability
        let model = SystemLanguageModel.default

        switch model.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible),
             .unavailable(.appleIntelligenceNotEnabled),
             .unavailable(.modelNotReady),
             .unavailable:
            // Fall back to raw text if model unavailable
            throw CleanupError.modelUnavailable
        @unknown default:
            throw CleanupError.modelUnavailable
        }

        // Create session with cleanup instructions
        let instructions = """
        You are a text cleanup assistant. Your job is to fix punctuation, \
        capitalization, and remove filler words (um, uh, like, you know).

        Output only the cleaned text with no extra commentary or explanations.
        Do not add content that wasn't spoken.
        """

        let session = LanguageModelSession(instructions: instructions)

        do {
            let response = try await session.respond(to: rawText)
            let cleanedText = response.content

            // If cleanup returns empty, fall back to raw
            return cleanedText.isEmpty ? rawText : cleanedText
        } catch {
            throw CleanupError.cleanupFailed
        }
    }
}
