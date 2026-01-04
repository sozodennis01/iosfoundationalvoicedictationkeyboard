import XCTest
@testable import localspeechtotext_keyboard

class DictationStateTests: XCTestCase {
    func testCodableEncoding() {
        let state = DictationState(
            rawText: "um hello world",
            cleanedText: "Hello world",
            status: .ready,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try? encoder.encode(state)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        let decoded = try? decoder.decode(DictationState.self, from: data!)
        XCTAssertEqual(decoded?.rawText, state.rawText)
        XCTAssertEqual(decoded?.cleanedText, state.cleanedText)
        XCTAssertEqual(decoded?.status, state.status)
    }

    func testDictationStatusRawValues() {
        XCTAssertEqual(DictationStatus.idle.rawValue, "idle")
        XCTAssertEqual(DictationStatus.recording.rawValue, "recording")
        XCTAssertEqual(DictationStatus.processing.rawValue, "processing")
        XCTAssertEqual(DictationStatus.ready.rawValue, "ready")
        XCTAssertEqual(DictationStatus.error.rawValue, "error")
    }

    func testDictationStatusDecoding() {
        // Test that status can be decoded from raw value
        let idleStatus = DictationStatus(rawValue: "idle")
        XCTAssertEqual(idleStatus, .idle)

        let recordingStatus = DictationStatus(rawValue: "recording")
        XCTAssertEqual(recordingStatus, .recording)

        let processingStatus = DictationStatus(rawValue: "processing")
        XCTAssertEqual(processingStatus, .processing)

        let readyStatus = DictationStatus(rawValue: "ready")
        XCTAssertEqual(readyStatus, .ready)

        let errorStatus = DictationStatus(rawValue: "error")
        XCTAssertEqual(errorStatus, .error)
    }
}
