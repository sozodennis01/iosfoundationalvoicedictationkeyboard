import XCTest
import Speech
@testable import localspeechtotext_keyboard

@available(iOS 26.0, *)
class SpeechRecognitionServiceTests: XCTestCase {
    func testServiceInitialization() {
        let service = SpeechRecognitionService()
        XCTAssertNotNil(service)
    }

    func testInitialRecordingState() {
        let service = SpeechRecognitionService()
        XCTAssertFalse(service.isRecording)
    }

    func testPermissionCheckDoesNotCrash() {
        let service = SpeechRecognitionService()
        service.checkPermissions()
        // If we get here without crashing, the test passes
        XCTAssertNotNil(service)
    }

    func testStopTranscriptionWhenNotRecording() {
        let service = SpeechRecognitionService()
        // Should not crash when stopping without starting
        service.stopTranscription()
        XCTAssertFalse(service.isRecording)
    }

    // Note: Actual speech recognition requires microphone and cannot be unit tested
    // Use manual device testing for full speech flow
}
