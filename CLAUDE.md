# Voice Dictation Keyboard for iOS

## Project Overview
iOS keyboard extension with on-device voice dictation using Apple's native APIs. Inspired by Wispr Flow.

## Tech Stack
- **Platform**: iOS 26+
- **Language**: Swift / SwiftUI
- **Speech-to-Text**: `SpeechTranscriber` (Speech framework)
- **Text Cleanup**: `FoundationModels` (Apple's on-device LLM)
- **No external dependencies** - Apple frameworks only

## Architecture
```
Host App (mic + processing) → App Group → Keyboard Extension (insert text)
```

- **Host App**: Captures audio, runs speech recognition, cleans up text via LLM
- **Keyboard Extension**: Minimal UI with mic button, reads cleaned text from App Group, inserts into any app
- **Communication**: App Group shared storage (`group.sozodennis.voicedictation`)

## Key Constraint
iOS keyboard extensions **cannot access the microphone**. The keyboard opens the host app to record, then returns cleaned text via App Group. This is the same pattern used by Wispr Flow.

## Project Structure
```
localspeechtotext_keyboard/
├── localspeechtotext_keyboard/     # Host App
│   ├── Services/                   # Speech, LLM, Storage services
│   └── Views/                      # DictationView, SettingsView
├── VoiceDictationKeyboard/         # Keyboard Extension
├── Shared/                         # Models & Constants (both targets)
├── Tests/                          # Unit & Integration Tests
│   ├── SharedTests/                # Tests for shared models
│   ├── ServiceTests/               # Tests for services
│   └── IntegrationTests/           # Cross-component tests
└── IMPLEMENTATION_PLAN.md          # Detailed implementation guide
```

## Implementation Status
See `IMPLEMENTATION_PLAN.md` for full plan and checklist.

**Current Phase**: Core services implemented and building successfully.

✅ `SpeechRecognitionService.swift` - Live mic transcription with SpeechAnalyzer
✅ `TextCleanupService.swift` - LLM cleanup with availability checking
✅ `SharedStorageService.swift` - App Group communication
✅ Views (DictationView, SettingsView, ContentView) - Basic UI implemented

## Key Files Reference

| File | Purpose |
|------|---------|
| `Services/SpeechRecognitionService.swift` | On-device STT via SpeechTranscriber |
| `Services/TextCleanupService.swift` | LLM cleanup via FoundationModels |
| `Services/SharedStorageService.swift` | App Group read/write |
| `VoiceDictationKeyboard/KeyboardViewController.swift` | Keyboard extension controller |
| `Shared/Constants/AppGroupIdentifier.swift` | Shared constants |

## Bundle Identifiers
- **Host App**: `sozodennis.localspeechtotext-keyboard`
- **Keyboard**: `sozodennis.localspeechtotext-keyboard.keyboard`
- **App Group**: `group.sozodennis.voicedictation`
- **URL Scheme**: `voicedictation://`

## Key APIs

### Keyboard Text Insertion
```swift
textDocumentProxy.insertText("cleaned text here")
```

---

## iOS 26 API Guide (IMPORTANT FOR FUTURE AGENTS)

These APIs are new in iOS 26 and documentation is limited. This guide captures working patterns.

### SpeechAnalyzer + SpeechTranscriber (Live Microphone)

**⚠️ Common Mistakes to Avoid:**
- `SFSpeechRecognizer.authorizationStatus(preset:)` - DOES NOT EXIST
- `SFSpeechRecognizer.requestAuthorization(preset:)` - DOES NOT EXIST
- `analyzer.analyze(buffer)` / `analyzer.append(buffer)` / `analyzer.process(buffer)` - NONE OF THESE EXIST

**✅ Correct Pattern for Live Mic Transcription:**

```swift
import Speech
import AVFoundation

// 1. Create transcriber with default locale
let transcriber = SpeechTranscriber(
    locale: Locale.current,  // Use default locale, not hardcoded
    transcriptionOptions: [],
    reportingOptions: [.volatileResults],  // For real-time updates
    attributeOptions: []
)

// 2. Create analyzer with transcriber module
let analyzer = SpeechAnalyzer(modules: [transcriber])

// 3. Get best audio format for the analyzer
let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

// 4. Create AsyncStream for feeding audio (THIS IS THE KEY!)
let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()

// 5. Start analyzer with input sequence
Task {
    try await analyzer.start(inputSequence: inputSequence)
}

// 6. Consume results (throws - must use try)
Task {
    do {
        for try await result in transcriber.results {
            let text = String(result.text.characters)  // result.text is AttributedString
            // Use text...
        }
    } catch {
        // Handle error
    }
}

// 7. Feed audio buffers via the continuation
func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    inputBuilder.yield(AnalyzerInput(buffer: buffer))
}

// 8. Stop by finishing the stream
inputBuilder.finish()
```

**✅ Correct Permission Handling:**

```swift
// Check permission (no parameters!)
let status = SFSpeechRecognizer.authorizationStatus()

// Request permission (callback-based, wrap in async)
func requestPermissions() async -> Bool {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status == .authorized)
        }
    }
}

// Microphone permission
let micGranted = await AVAudioApplication.requestRecordPermission()
```

### FoundationModels (Apple Intelligence LLM)

**✅ Always Check Availability First:**

```swift
import FoundationModels

let model = SystemLanguageModel.default
switch model.availability {
case .available:
    // Safe to use
case .unavailable(.deviceNotEligible):
    // Device doesn't support Apple Intelligence
case .unavailable(.appleIntelligenceNotEnabled):
    // User needs to enable in Settings
case .unavailable(.modelNotReady):
    // Model still loading, retry later
case .unavailable:
    // Other unavailable state
@unknown default:
    // Handle future cases
}
```

**✅ Basic Text Generation:**

```swift
let session = LanguageModelSession()
let response = try await session.respond(to: "Your prompt here")
let text = response.content  // This is a String
```

**✅ With Instructions:**

```swift
let instructions = """
You are a text cleanup assistant.
Fix punctuation and remove filler words.
Output only the cleaned text.
"""
let session = LanguageModelSession(instructions: instructions)
let response = try await session.respond(to: rawText)
```

### Swift Concurrency Gotchas

**❌ Don't use `||` with async in autoclosure:**
```swift
// This will NOT compile:
guard hasPermission || await requestPermissions() else { return }
```

**✅ Do this instead:**
```swift
var hasPermission = self.hasPermission
if !hasPermission {
    hasPermission = await requestPermissions()
}
guard hasPermission else { return }
```

### Reference Documentation
- SpeechAnalyzer: https://developer.apple.com/documentation/speech/speechanalyzer
- FoundationModels: https://developer.apple.com/documentation/FoundationModels
- WWDC25 SpeechAnalyzer: https://developer.apple.com/videos/play/wwdc2025/277/

## User Flow
1. User taps mic in keyboard
2. Opens host app via URL scheme
3. Records speech → real-time transcript
4. LLM cleans up text
5. Saves to App Group
6. User returns to original app
7. Keyboard shows "Insert" button
8. Text inserted

## Testing Strategy

### Unit Tests (Automated via XCTest)
Write unit tests for components that don't require hardware:

**Shared Models:**
- `DictationState`: Codable encoding/decoding
- `AppConstants`: Validate constants

**Services (with mocking):**
- `SharedStorageService`: Mock UserDefaults, test save/read operations
- `TextCleanupService`: Mock LLM responses, test prompt formatting
- `SpeechRecognitionService`: Test permission states, error handling

### Integration Tests (Automated)
- App Group communication between targets
- URL scheme handling and routing
- State transitions (idle → recording → processing → ready)

### End-to-End Tests (Manual on Hardware Device)
**Cannot be automated** - requires real device testing:
- Real microphone input and speech recognition
- Actual LLM text cleanup quality
- Keyboard extension in different apps (Messages, Notes, Safari)
- Full dictation workflow
- Permission prompts and user interactions

### Test Commands
```bash
# Run all unit tests
xcodebuild test -scheme localspeechtotext_keyboard -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test suite
xcodebuild test -scheme localspeechtotext_keyboard -only-testing:SharedTests

# Run tests from Xcode
# Cmd+U or Product → Test
```

### Coverage Goals
- **Shared models**: 100% (simple data structures)
- **Services**: 80%+ (business logic, with mocked dependencies)
- **Views**: Manual testing only (SwiftUI previews + device)
- **E2E flow**: Manual device testing required

## Commands

```bash
# Open in Xcode
open localspeechtotext_keyboard.xcodeproj

# Build (from Xcode or xcodebuild)
xcodebuild -scheme localspeechtotext_keyboard -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Manual Xcode Steps Required
1. Add keyboard extension target (File → New → Target → Custom Keyboard Extension)
2. Enable App Groups capability on both targets
3. Add URL scheme `voicedictation` to host app
4. Add microphone + speech recognition usage descriptions to Info.plist

## Notes for Future Sessions
- **READ THE iOS 26 API GUIDE ABOVE** - These APIs are new and easy to get wrong
- Always check `IMPLEMENTATION_PLAN.md` for current progress
- Keyboard extension requires `RequestsOpenAccess = YES` in Info.plist
- Test on real device - keyboard extensions don't work well in simulator
- LLM has cold start latency on first call - show loading indicator
- Write unit tests for all services and models as you implement them
- Manual E2E testing must be done by user on physical iOS device
- Run tests with `Cmd+U` in Xcode or via `xcodebuild test` command
- When searching for iOS 26 API docs, include "WWDC25" or "2025" in search queries
- The SpeechAnalyzer uses AsyncStream pattern - don't guess method names like `analyze()` or `process()`
