import XCTest
@testable import localspeechtotext_keyboard

@available(iOS 26.0, *)
class TextCleanupServiceTests: XCTestCase {
    func testPromptFormatting() {
        let service = TextCleanupService()
        let prompt = service.createCleanupPrompt(rawText: "um hello world")

        // Verify prompt contains instructions
        XCTAssertTrue(prompt.contains("Fix punctuation"))
        XCTAssertTrue(prompt.contains("Remove filler words"))
        XCTAssertTrue(prompt.contains("um hello world"))
    }

    func testPromptContainsRawText() {
        let service = TextCleanupService()
        let testText = "this is a test with um and uh filler words"
        let prompt = service.createCleanupPrompt(rawText: testText)

        XCTAssertTrue(prompt.contains(testText))
    }

    func testPromptStructure() {
        let service = TextCleanupService()
        let prompt = service.createCleanupPrompt(rawText: "test")

        // Verify prompt has the expected structure
        XCTAssertTrue(prompt.contains("Raw transcript:"))
        XCTAssertTrue(prompt.contains("Cleaned text:"))
    }

    // Note: Actual LLM calls require device and cannot be unit tested
    // Use integration tests or manual testing for full cleanup flow
}
