import XCTest
@testable import localspeechtotext_keyboard

class SharedStorageServiceTests: XCTestCase {
    var service: SharedStorageService!
    var mockDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        // Use in-memory suite for testing
        mockDefaults = UserDefaults(suiteName: "test.suite")!
        service = SharedStorageService(userDefaults: mockDefaults)
    }

    override func tearDown() {
        mockDefaults.removePersistentDomain(forName: "test.suite")
        super.tearDown()
    }

    func testSaveAndGetText() {
        service.saveText("Hello world")
        let retrieved = service.getText()
        XCTAssertEqual(retrieved, "Hello world")
    }

    func testSaveAndGetState() {
        let state = DictationState(
            rawText: "test",
            cleanedText: "Test",
            status: .ready,
            timestamp: Date()
        )

        service.saveState(state)
        let retrieved = service.getState()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.rawText, "test")
        XCTAssertEqual(retrieved?.cleanedText, "Test")
        XCTAssertEqual(retrieved?.status, .ready)
    }

    func testGetTextReturnsNilWhenEmpty() {
        XCTAssertNil(service.getText())
    }

    func testGetStateReturnsNilWhenEmpty() {
        XCTAssertNil(service.getState())
    }

    func testClearAll() {
        // Save some data
        service.saveText("Hello world")
        let state = DictationState(
            rawText: "test",
            cleanedText: "Test",
            status: .ready,
            timestamp: Date()
        )
        service.saveState(state)

        // Verify data exists
        XCTAssertNotNil(service.getText())
        XCTAssertNotNil(service.getState())

        // Clear all
        service.clearAll()

        // Verify data is cleared
        XCTAssertNil(service.getText())
        XCTAssertNil(service.getState())
    }

    func testMultipleTextUpdates() {
        service.saveText("First")
        XCTAssertEqual(service.getText(), "First")

        service.saveText("Second")
        XCTAssertEqual(service.getText(), "Second")

        service.saveText("Third")
        XCTAssertEqual(service.getText(), "Third")
    }
}
