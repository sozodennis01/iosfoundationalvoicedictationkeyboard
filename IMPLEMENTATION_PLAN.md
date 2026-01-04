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

## Testing Checklist

- [ ] Host app requests microphone permission correctly
- [ ] Host app requests speech recognition permission correctly
- [ ] Speech transcription works in real-time
- [ ] LLM cleanup improves text quality
- [ ] Text saves to App Group correctly
- [ ] Keyboard extension can read from App Group
- [ ] URL scheme opens host app from keyboard
- [ ] Insert button works in keyboard
- [ ] Works across different apps (Messages, Notes, Safari)

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
