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

**Current Phase**: Project setup - structure and files need to be created.

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

### Speech Recognition
```swift
import Speech
let transcriber = SpeechTranscriber(locale: Locale(identifier: "en_US"))
```

### Text Cleanup
```swift
import FoundationModels
let session = LanguageModelSession()
let response = try await session.respond(to: prompt)
```

### Keyboard Text Insertion
```swift
textDocumentProxy.insertText("cleaned text here")
```

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
- Always check `IMPLEMENTATION_PLAN.md` for current progress
- Keyboard extension requires `RequestsOpenAccess = YES` in Info.plist
- Test on real device - keyboard extensions don't work well in simulator
- LLM has cold start latency on first call - show loading indicator
- Write unit tests for all services and models as you implement them
- Manual E2E testing must be done by user on physical iOS device
- Run tests with `Cmd+U` in Xcode or via `xcodebuild test` command
