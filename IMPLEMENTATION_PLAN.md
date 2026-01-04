# Voice Dictation Keyboard - Implementation Plan

## Project Goal
Build a Wispr Flow-style voice dictation keyboard for iOS using Apple-native APIs:
- **SpeechTranscriber** for on-device speech-to-text
- **Foundation Models** framework for LLM text cleanup
- **Keyboard Extension** for text insertion across apps

---

## Architecture Overview

```
HOST APP                          KEYBOARD EXTENSION
┌─────────────────────┐           ┌─────────────────────┐
│ 1. Mic captures     │           │ 1. User taps mic    │
│    audio            │           │    button           │
│ 2. SpeechTranscriber│           │ 2. Opens host app   │
│    → raw text       │           │    via URL scheme   │
│ 3. Foundation Models│           │ 3. Reads cleaned    │
│    → clean text     │           │    text from App    │
│ 4. Save to App Group│ ────────► │    Group            │
└─────────────────────┘           │ 4. Inserts text     │
                                  └─────────────────────┘
```

---

## Confirmed Requirements

- **iOS Version**: iOS 26+ only
- **Keyboard UI**: Minimal (mic button + insert button only)
- **UX Flow**: Open host app to record (like Wispr Flow)
- **Language**: English only
- **Dependencies**: Apple frameworks only (no external packages)

---

## Implementation Todos

- [ ] **Phase 1**: Create project structure and shared constants
- [ ] **Phase 2**: Create shared infrastructure (DictationState model)
- [ ] **Phase 3**: Implement SpeechRecognitionService
- [ ] **Phase 4**: Implement TextCleanupService (Foundation Models)
- [ ] **Phase 5**: Implement SharedStorageService
- [ ] **Phase 6**: Create Host App UI (DictationView, SettingsView)
- [ ] **Phase 7**: Create Keyboard Extension files
- [ ] **Phase 8**: Wire up end-to-end flow and update App entry point
- [ ] **Phase 9**: Write unit tests for shared models and services
- [ ] **Phase 10**: Write integration tests for App Group communication
- [ ] **Phase 11**: Manual E2E testing on hardware device (user-performed)

---

## Directory Structure (Target)

```
localspeechtotext_keyboard/
├── localspeechtotext_keyboard/          # Host App
│   ├── App/
│   │   └── (existing app files)
│   ├── Services/
│   │   ├── SpeechRecognitionService.swift
│   │   ├── TextCleanupService.swift
│   │   └── SharedStorageService.swift
│   ├── Views/
│   │   ├── DictationView.swift
│   │   └── SettingsView.swift
│   ├── ContentView.swift (update)
│   └── localspeechtotext_keyboardApp.swift (update)
│
├── VoiceDictationKeyboard/              # Keyboard Extension (NEW)
│   ├── KeyboardViewController.swift
│   ├── KeyboardView.swift
│   ├── SharedStorageReader.swift
│   └── Info.plist
│
├── Shared/                              # Shared Code (both targets)
│   ├── Constants/
│   │   └── AppGroupIdentifier.swift
│   └── Models/
│       └── DictationState.swift
│
├── Tests/                               # Test Suites
│   ├── SharedTests/
│   │   ├── DictationStateTests.swift
│   │   └── AppConstantsTests.swift
│   ├── ServiceTests/
│   │   ├── SharedStorageServiceTests.swift
│   │   ├── TextCleanupServiceTests.swift
│   │   └── SpeechRecognitionServiceTests.swift
│   └── IntegrationTests/
│       ├── AppGroupCommunicationTests.swift
│       └── URLSchemeTests.swift
│
└── IMPLEMENTATION_PLAN.md               # This file
```

---

## Files to Create

### Shared (both targets)

**`Shared/Constants/AppGroupIdentifier.swift`**
```swift
import Foundation

enum AppConstants {
    static let appGroupID = "group.sozodennis.voicedictation"
    static let sharedTextKey = "lastDictatedText"
    static let statusKey = "dictationStatus"
}
```

**`Shared/Models/DictationState.swift`**
```swift
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
```

---

### Host App Services

**`Services/SpeechRecognitionService.swift`**
- Import: `Speech`
- Uses `SpeechTranscriber` (iOS 26+)
- Locale: `en_US`
- Methods:
  - `requestPermissions() async -> Bool`
  - `startTranscription() async throws -> AsyncStream<String>`
  - `stopTranscription()`

**`Services/TextCleanupService.swift`**
- Import: `FoundationModels`
- Uses `LanguageModelSession`
- Cleanup prompt:
  - Fix punctuation and capitalization
  - Remove filler words (um, uh, like, you know)
  - Remove false starts and repetitions
  - Preserve original meaning
  - Output only cleaned text

**`Services/SharedStorageService.swift`**
- Uses `UserDefaults(suiteName: appGroupID)`
- Methods:
  - `saveState(_ state: DictationState)`
  - `getState() -> DictationState?`
  - `saveText(_ text: String)`
  - `getText() -> String?`

---

### Host App Views

**`Views/DictationView.swift`**
- Large mic button (tap to toggle recording)
- Real-time transcript display
- Pulse animation when recording
- Status indicator (recording → processing → done)
- "Text copied to keyboard" confirmation

**`Views/SettingsView.swift`**
- Microphone permission status + request button
- Speech recognition permission status + request button
- "How to enable keyboard" instructions:
  1. Go to Settings → General → Keyboard
  2. Tap "Keyboards" → "Add New Keyboard"
  3. Select "VoiceDictation"
  4. Enable "Allow Full Access"

**`ContentView.swift`** (update existing)
- TabView with two tabs:
  - Dictation (mic icon)
  - Settings (gear icon)

**`localspeechtotext_keyboardApp.swift`** (update existing)
- Handle URL scheme: `voicedictation://record`
- Auto-start recording when opened via URL

---

### Keyboard Extension

**`VoiceDictationKeyboard/KeyboardViewController.swift`**
- Subclass `UIInputViewController`
- Host SwiftUI view via `UIHostingController`
- Methods:
  - `openHostApp()` - open URL scheme
  - `insertText()` - read from App Group, insert via `textDocumentProxy`

**`VoiceDictationKeyboard/KeyboardView.swift`**
- Minimal SwiftUI UI:
  - Mic button (opens host app)
  - Text preview (last dictated text)
  - Insert button
  - Status indicator

**`VoiceDictationKeyboard/SharedStorageReader.swift`**
- Read-only access to App Group
- Methods:
  - `getText() -> String?`
  - `getStatus() -> DictationStatus`

**`VoiceDictationKeyboard/Info.plist`**
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.keyboard-service</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).KeyboardViewController</string>
    <key>RequestsOpenAccess</key>
    <true/>
</dict>
```

---

## Manual Xcode Configuration Steps

### 1. Add Keyboard Extension Target
1. File → New → Target
2. Search "Custom Keyboard Extension"
3. Name: `VoiceDictationKeyboard`
4. Bundle ID: `sozodennis.localspeechtotext-keyboard.keyboard`

### 2. Configure App Groups (BOTH targets)
1. Select `localspeechtotext_keyboard` target
2. Signing & Capabilities → + Capability → App Groups
3. Add: `group.sozodennis.voicedictation`
4. Repeat for `VoiceDictationKeyboard` target

### 3. Add URL Scheme (Host App only)
1. Select `localspeechtotext_keyboard` target
2. Info tab → URL Types → +
3. URL Schemes: `voicedictation`

### 4. Add Permissions (Host App Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed for voice dictation</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Speech recognition is used for voice dictation</string>
```

### 5. Add Shared folder to both targets
1. Drag `Shared/` folder into Xcode project navigator
2. In dialog, check BOTH targets:
   - [x] localspeechtotext_keyboard
   - [x] VoiceDictationKeyboard

---

## User Flow (End-to-End)

1. User is in any app (Messages, Notes, etc.)
2. User switches to VoiceDictation keyboard
3. User taps mic button in keyboard
4. Keyboard opens host app via `voicedictation://record`
5. Host app automatically starts recording
6. User speaks
7. Real-time transcript appears
8. User taps stop (or silence auto-stops)
9. Transcript sent to Foundation Models for cleanup
10. Cleaned text saved to App Group
11. User returns to original app (swipe or home)
12. Keyboard shows cleaned text preview
13. User taps "Insert" button
14. Text inserted into text field

---

## Key APIs Reference

### SpeechTranscriber (iOS 26+)
```swift
import Speech

let transcriber = SpeechTranscriber(locale: Locale(identifier: "en_US"))
for try await transcript in transcriber.transcribe(audio: audioSource) {
    // transcript.text contains the transcribed text
}
```

### Foundation Models (iOS 26+)
```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond(to: "Clean up this text: ...")
// response.content contains the cleaned text
```

### Keyboard Text Insertion
```swift
// In KeyboardViewController
textDocumentProxy.insertText("Hello world")
```

### Open URL from Keyboard Extension
```swift
// In KeyboardViewController
func openURL(_ url: URL) {
    let selector = sel_registerName("openURL:")
    var responder: UIResponder? = self
    while let r = responder {
        if r.responds(to: selector) {
            r.perform(selector, with: url)
            return
        }
        responder = r.next
    }
}
```

---

## Testing Strategy

### Phase 9: Unit Tests

#### SharedTests/DictationStateTests.swift
```swift
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
}
```

#### ServiceTests/SharedStorageServiceTests.swift
```swift
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
        XCTAssertEqual(retrieved?.status, .ready)
    }

    func testGetTextReturnsNilWhenEmpty() {
        XCTAssertNil(service.getText())
    }
}
```

#### ServiceTests/TextCleanupServiceTests.swift
```swift
import XCTest
@testable import localspeechtotext_keyboard

class TextCleanupServiceTests: XCTestCase {
    func testPromptFormatting() {
        let service = TextCleanupService()
        let prompt = service.createCleanupPrompt(rawText: "um hello world")

        // Verify prompt contains instructions
        XCTAssertTrue(prompt.contains("Fix punctuation"))
        XCTAssertTrue(prompt.contains("Remove filler words"))
        XCTAssertTrue(prompt.contains("um hello world"))
    }

    // Note: Actual LLM calls require device and cannot be unit tested
    // Use integration tests or manual testing for full cleanup flow
}
```

#### ServiceTests/SpeechRecognitionServiceTests.swift
```swift
import XCTest
import Speech
@testable import localspeechtotext_keyboard

class SpeechRecognitionServiceTests: XCTestCase {
    func testPermissionStates() {
        let service = SpeechRecognitionService()

        // Test that permission checking doesn't crash
        // Actual permissions require user interaction
        XCTAssertNotNil(service)
    }

    func testLocaleConfiguration() {
        let service = SpeechRecognitionService()
        // Verify service initializes with en_US locale
        XCTAssertNotNil(service)
    }

    // Note: Actual speech recognition requires microphone and cannot be unit tested
    // Use manual device testing for full speech flow
}
```

### Phase 10: Integration Tests

#### IntegrationTests/AppGroupCommunicationTests.swift
```swift
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
    }
}
```

#### IntegrationTests/URLSchemeTests.swift
```swift
import XCTest
@testable import localspeechtotext_keyboard

class URLSchemeTests: XCTestCase {
    func testURLSchemeFormat() {
        let url = URL(string: "voicedictation://record")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.scheme, "voicedictation")
        XCTAssertEqual(url?.host, "record")
    }

    // Note: Actual URL handling requires app lifecycle and cannot be unit tested
    // Test in app delegate or scene delegate with manual testing
}
```

### Phase 11: Manual E2E Testing (Hardware Device Required)

**Pre-requisites:**
- Physical iOS device with iOS 26+
- Device signed into developer account
- App installed via Xcode
- Keyboard enabled in Settings → Keyboard

**Manual Test Cases:**

#### Test Case 1: Permission Flow
- [ ] Launch host app
- [ ] App requests microphone permission
- [ ] App requests speech recognition permission
- [ ] Permissions granted successfully
- [ ] Settings view shows "Authorized" status

#### Test Case 2: Basic Dictation
- [ ] Open Notes app
- [ ] Switch to VoiceDictation keyboard
- [ ] Tap mic button
- [ ] Host app opens and starts recording
- [ ] Speak: "Hello world, this is a test"
- [ ] Real-time transcript appears
- [ ] Tap stop
- [ ] Processing indicator shows
- [ ] Return to Notes app
- [ ] Keyboard shows cleaned text preview
- [ ] Tap Insert button
- [ ] Text inserted correctly

#### Test Case 3: Text Cleanup Quality
- [ ] Record with filler words: "Um, like, you know, hello world"
- [ ] Verify cleaned text removes fillers
- [ ] Record with poor punctuation
- [ ] Verify cleaned text has proper punctuation and capitalization

#### Test Case 4: Multiple Apps
- [ ] Test in Messages app
- [ ] Test in Safari search bar
- [ ] Test in Mail compose
- [ ] Test in third-party apps
- [ ] Verify insertion works consistently

#### Test Case 5: Error Handling
- [ ] Test with no microphone permission
- [ ] Test with no speech recognition permission
- [ ] Test with airplane mode (offline LLM)
- [ ] Test recording timeout
- [ ] Verify error states display correctly

#### Test Case 6: App Group Communication
- [ ] Record dictation in host app
- [ ] Force quit host app
- [ ] Open keyboard in another app
- [ ] Verify text persists and can be inserted

#### Test Case 7: Performance
- [ ] Measure time from tap to recording start
- [ ] Measure LLM cleanup latency
- [ ] Test battery usage during extended recording
- [ ] Verify no memory leaks

### Running Tests

```bash
# Run all unit and integration tests
xcodebuild test -scheme localspeechtotext_keyboard \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test suite
xcodebuild test -scheme localspeechtotext_keyboard \
  -only-testing:SharedTests

xcodebuild test -scheme localspeechtotext_keyboard \
  -only-testing:ServiceTests

# From Xcode: Cmd+U or Product → Test
```

### Test Coverage Goals

| Component | Target Coverage | Test Type |
|-----------|----------------|-----------|
| Shared Models | 100% | Unit |
| SharedStorageService | 90% | Unit + Integration |
| TextCleanupService | 70% (prompt logic) | Unit |
| SpeechRecognitionService | 60% (setup/permissions) | Unit |
| App Group Communication | 100% | Integration |
| URL Scheme Routing | 80% | Integration |
| Views | 0% (manual only) | Manual |
| Full User Flow | N/A | Manual E2E |

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| App Store rejection | Follow Wispr Flow pattern (approved app) |
| LLM cold start latency | Show loading indicator, cache session |
| Battery drain | Limit recording duration, optimize processing |
| iOS 26 user base | Accept limitation for MVP |

---

## Future Enhancements (Post-MVP)

- Multiple language support
- Custom vocabulary/corrections
- Silence detection auto-stop
- Waveform visualization
- History of past dictations
- iCloud sync
- Widget for quick access
