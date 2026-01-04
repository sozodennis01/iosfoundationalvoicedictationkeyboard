import XCTest
@testable import localspeechtotext_keyboard

class AppConstantsTests: XCTestCase {
    func testAppGroupID() {
        XCTAssertEqual(AppConstants.appGroupID, "group.sozodennis.voicedictation")
    }

    func testSharedTextKey() {
        XCTAssertEqual(AppConstants.sharedTextKey, "lastDictatedText")
    }

    func testStatusKey() {
        XCTAssertEqual(AppConstants.statusKey, "dictationStatus")
    }

    func testAppGroupIDFormat() {
        // Verify the App Group ID starts with "group."
        XCTAssertTrue(AppConstants.appGroupID.hasPrefix("group."))
    }
}
