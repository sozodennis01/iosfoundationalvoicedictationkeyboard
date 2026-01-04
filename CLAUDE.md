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
