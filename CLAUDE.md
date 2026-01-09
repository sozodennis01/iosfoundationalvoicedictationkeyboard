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

## Commands

```bash
# Build (from Xcode or xcodebuild)
xcodebuild -scheme localspeechtotext_keyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Wispr Flow Implementation (✅ IMPLEMENTED)

### Architecture Overview

**🎯 Core Pattern:** Background audio recording with Live Activities + Darwin Notifications

The implementation follows the Wispr Flow pattern with these key components:

#### 1. **Background Audio Session** ✅
```swift
// In SpeechRecognitionService.swift
let audioSession = AVAudioSession.sharedInstance()
try audioSession.setCategory(
    .playAndRecord,
    mode: .default,
    options: [.mixWithOthers, .defaultToSpeaker]
)
try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
```

#### 2. **Live Activities (Dynamic Island)** ✅
```swift
// In LiveActivityService.swift
let activity = try Activity.request(
    attributes: RecordingActivityAttributes(name: "Voice Dictation"),
    content: .init(state: initialState, staleDate: nil)
)
// Updates status in Dynamic Island: "Listening..." → "Processing..." → "Complete"
```

#### 3. **Darwin Notifications (Cross-Process IPC)** ✅
```swift
// Host App posts notification when text is ready
DarwinNotificationCenter.post(.textReady)

// Keyboard Extension observes and auto-inserts text
darwinObserver = DarwinNotificationCenter.observe(.textReady) {
    self?.handleTextReadyNotification()
}
```

### Complete Flow (Wispr Flow Pattern)
1. User taps mic in keyboard → URL scheme opens host app
2. Host app configures background audio session → starts recording
3. **Live Activity started** → Dynamic Island shows "Listening..." with duration counter
4. User continues using any app while keyboard stays visible
5. User taps mic again to stop → recording stops
6. **Live Activity updates** → "Processing..." in Dynamic Island
7. Speech recognition → LLM text cleanup → save to App Group
8. **Darwin notification posted** → keyboard extension receives instantly
9. **Text auto-inserted** via `textDocumentProxy.insertText()`
10. **Live Activity ended** → Dynamic Island dismisses

### Key Files

| File | Purpose |
|------|---------|
| `Shared/Models/RecordingActivityAttributes.swift` | Live Activity model definition |
| `localspeechtotext_keyboard/Services/LiveActivityService.swift` | Manages Live Activities lifecycle |
| `Shared/Services/DarwinNotificationCenter.swift` | Cross-process notification wrapper |
| `localspeechtotext_keyboard/Services/SpeechRecognitionService.swift` | Background audio + speech recognition |
| `localspeechtotext_keyboard/Views/DictationView.swift` | Coordinates recording, cleanup, Live Activities |
| `VoiceDictationKeyboard/KeyboardState.swift` | Handles Darwin notifications + auto-insert |

### Configuration Files

**localspeechtotext-keyboard-Info.plist:**
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
<key>NSSupportsLiveActivities</key>
<true/>
```

### Why This Implementation Works
- ✅ **Background audio** allows recording while app is backgrounded
- ✅ **Live Activities** provide non-intrusive Dynamic Island status
- ✅ **Darwin Notifications** enable instant cross-process communication (no polling!)
- ✅ **Auto-insert** eliminates manual paste button tap
- ✅ **App Group** maintains data persistence between processes
- ✅ **URL scheme** triggers recording from keyboard extension

3. **Darwin Notifications** - Add real-time signaling between processes

---

## State Machines & Darwin Notification Protocol

### 🔄 **Keyboard Extension State Machine**
```
                    ┌─────────────────────────────────────┐
                    │                                     │
                    ▼                                     │
┌─────────┐   mic pressed   ┌────────────┐  recordingStarted  ┌───────────┐
│  IDLE   │ ─────────────►  │ PROCESSING │ ────────────────►  │ RECORDING │
└─────────┘                 └────────────┘                    └───────────┘
     ▲                           │                                │   │
     │                           │                                │   │
     │                           │ textReady                      │   │
     │                           │ notification                   │   │ x pressed
     │    ┌────────────┐        │                                │   │ (cancel)
     │◄───│ AUTO-INSERT│◄───────┘                                │   │
     │    └────────────┘                                         │   │
     │                                                           │   │
     │                      ┌────────────┐  ✓ pressed            │   │
     │                      │ PROCESSING │◄──────────────────────┘   │
     │                      │ (cleanup)  │                           │
     │                      └────────────┘                           │
     │                           │                                   │
     │                           │ textReady                         │
     │◄──────────────────────────┘                                   │
     │                                                               │
     └───────────────────────────────────────────────────────────────┘
```

### 🔄 **Host App State Machine**
```
┌─────────┐  startRecording OR URL    ┌───────────┐  stopRecording  ┌────────────┐
│  IDLE   │ ─────────────────────►    │ RECORDING │ ─────────────►  │ PROCESSING │
└─────────┘                           └───────────┘                 └────────────┘
     ▲                                   │                              │
     │                                   │ cancelRecording              │
     │◄──────────────────────────────────┘                              │
     │                                                                  │
     │                          textReady notification                  │
     │◄─────────────────────────────────────────────────────────────────┘
```

### 📨 **Darwin Notification Protocol**

| Notification | Direction | Purpose |
|-------------|-----------|---------|
| `hostAppReady` | Host → Keyboard | Host app is initialized and ready |
| `startRecording` | Keyboard → Host | Command to start recording |
| `recordingStarted` | Host → Keyboard | Confirms recording has begun |
| `stopRecording` | Keyboard → Host | User pressed ✓, process audio |
| `cancelRecording` | Keyboard → Host | User pressed ✗, discard audio |
| `textReady` | Host → Keyboard | Cleaned text is ready, auto-insert |

### 🎯 **Complete User Flow (WisprFlow Pattern)**

1. **User opens host app once** → Host calls `SharedState.setHostAppReady(true)` → Persists state + Darwin notify

2. **Keyboard activates via viewWillAppear:**
   - Checks `SharedState.isHostAppReady()` from App Group
   - Sets up Darwin notification observer for state changes

3. **User taps mic in keyboard:**
   - `SharedState.isHostAppReady() == false` → Open URL scheme → Host app opens → Calls `SharedState.setHostAppReady(true)` → Darwin notifies keyboard → Shows x/✓ buttons + posts `startRecording`
   - `SharedState.isHostAppReady() == true` → Shows x/✓ buttons immediately + posts `startRecording` (no URL open needed!)

4. **Keyboard shows ✗ and ✓ buttons** (status = `.recording`)
   - Host app receives `startRecording` → Starts recording → Posts `recordingStarted`
   - Host app shows Live Activities while recording in background

5. **User presses ✗ (cancel):**
   - Post `cancelRecording` → Host discards audio → Returns to idle

6. **User presses ✓ (confirm):**
   - Post `stopRecording` → Host processes audio → STT → LLM cleanup → Saves to App Group → Posts `textReady`

7. **Keyboard receives `textReady`:**
   - Auto-reads from App Group → `textDocumentProxy.insertText()` → Returns to idle

### 🏗️ **Architecture Decisions**

- **Production-ready WisprFlow pattern:** Clean App Group UserDefaults + Darwin Notifications
- **Immediate keyboard updates:** Darwin notifications ensure running keyboards update instantly when state changes
- **True cross-process state sync:** No polling, instant notification delivery
- **Backwards compatible:** Works with segmented memory model (keyboard extension ≠ host app)
- **Persisted state:** Survives device reboots, keyboard restarts, app terminations
- **Live Activities:** Provide non-intrusive Dynamic Island status while recording continues in background
- **Auto-insertion:** Eliminates manual paste - text appears instantly in any iOS text field

## URI URL
bundle identifiers keyboard: sozodennis.localspeechtotext-keyboard.VoiceDictationKeyboard
bundle identifier host app: sozodennis.localspeechtotext-keyboard
app group: group.sozodennis.voicedictation
