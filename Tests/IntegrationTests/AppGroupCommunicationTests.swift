import XCTest
@testable import localspeechtotext_keyboard

class AppGroupCommunicationTests: XCTestCase {
    func testAppGroupSharedDefaults() {
        // Test that App Group suite can be created
        let appGroup = UserDefaults(suiteName: AppConstants.appGroupID)
        XCTAssertNotNil(appGroup)

        // Test write from host app
        appGroup?.set("test data", forKey: AppConstants.sharedTextKey)

        // Test read from keyboard extension
        let retrieved = appGroup?.string(forKey: AppConstants.sharedTextKey)
        XCTAssertEqual(retrieved, "test data")

        // Cleanup
        appGroup?.removeObject(forKey: AppConstants.sharedTextKey)
    }

    func testStateSharing() {
        let state = DictationState(
            rawText: "test",
            cleanedText: "Test",
            status: .ready,
            timestamp: Date()
        )

        // Simulate host app saving
        let storage = SharedStorageService()
        storage.saveState(state)

        // Simulate keyboard extension reading
        let retrieved = storage.getState()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.cleanedText, "Test")
        XCTAssertEqual(retrieved?.rawText, "test")
        XCTAssertEqual(retrieved?.status, .ready)

        // Cleanup
        storage.clearAll()
    }

    func testCrossTargetCommunication() {
        // Test that both SharedStorageService and SharedStorageReader can access same data
        let storage = SharedStorageService()
        let reader = SharedStorageReader()

        // Save text via storage service (host app)
        storage.saveText("Cross-target test")

        // Read via reader (keyboard extension)
        let text = reader.getText()
        XCTAssertEqual(text, "Cross-target test")

        // Cleanup
        storage.clearAll()
    }

    func testStatusSynchronization() {
        let storage = SharedStorageService()
        let reader = SharedStorageReader()

        // Save different statuses and verify they sync
        let states: [DictationStatus] = [.idle, .recording, .processing, .ready, .error]

        for status in states {
            let state = DictationState(
                rawText: "",
                cleanedText: "",
                status: status,
                timestamp: Date()
            )

            storage.saveState(state)

            let retrievedStatus = reader.getStatus()
            XCTAssertEqual(retrievedStatus, status)
        }

        // Cleanup
        storage.clearAll()
    }
}
