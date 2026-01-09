# Voice Dictation Keyboard for iOS

## Project Overview
iOS keyboard extension with on-device voice dictation using Apple's native APIs. Inspired by Wispr Flow.

## Tech Stack
- **Platform**: iOS 26+
- **Language**: Swift / SwiftUI
- **Speech-to-Text**: `SpeechTranscriber` (Speech framework)
- **Text Cleanup**: `FoundationModels` (Apple's on-device LLM)
- **No external dependencies** - Apple frameworks only

## Architecture: Keyboard-Based Dictation Pattern

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     KEYBOARD-BASED DICTATION FLOW                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐     Darwin Notifications      ┌─────────────────┐ │
│  │    KEYBOARD     │ ─────────────────────────────►│  CONTAINER APP  │ │
│  │   EXTENSION     │◄───────────────────────────── │  (Background)   │ │
│  │                 │                               │                 │ │
│  │  • Mic button   │   startRecording ────────►   │  • Audio Engine │ │
│  │  • ✗/✓ buttons  │   stopRecording ─────────►   │  • STT Service  │ │
│  │  • Status UI    │   cancelRecording ───────►   │  • LLM Cleanup  │ │
│  │  • Text insert  │                               │  • Live Activity│ │
│  │                 │   ◄──────── recordingStarted  │                 │ │
│  │                 │   ◄──────── textReady         │                 │ │
│  └─────────────────┘                               └─────────────────┘ │
│          │                                                  │          │
│          └──────────────► App Group ◄───────────────────────┘          │
│                        (cleaned text)                                   │
└─────────────────────────────────────────────────────────────────────────┘
```

### Two Modes of Operation

| Mode | When | Behavior |
|------|------|----------|
| **Cold Start** | Container app never opened | Keyboard opens URI → Container initializes → Returns to keyboard → Recording starts |
| **Warm Start** | Container already initialized | Keyboard sends Darwin notification directly → Container (in background) starts recording |

### Component Responsibilities

- **Container App**:
  - Initializes audio engine + permissions on first launch
  - Runs in background via `UIBackgroundModes: audio`
  - Listens for Darwin notifications from keyboard
  - Performs all audio capture, STT, and LLM cleanup
  - Posts results to App Group + Darwin notification

- **Keyboard Extension**:
  - Checks `SharedState.isHostAppReady()` on mic tap
  - If cold: opens `voicedictation://` URI
  - If warm: sends `startRecording` Darwin notification directly
  - Shows ✗/✓ control buttons during recording
  - Auto-inserts cleaned text when `textReady` received

- **Communication**:
  - **Darwin Notifications**: Real-time commands (keyboard→app) and events (app→keyboard)
  - **App Group UserDefaults**: Persisted state + cleaned text storage

## Key Constraint
iOS keyboard extensions **cannot access the microphone directly**. However, once the container app initializes the audio engine with `UIBackgroundModes: audio`, the container continues running in background. The keyboard then commands the background container via Darwin notifications—no need to open the app again.

**This is the KeyboardKit `.keyboard` pattern**: Initialize once, then keyboard controls background recording.

## Key Files Reference

| File | Purpose |
|------|---------|
| `Services/SpeechRecognitionService.swift` | On-device STT via SpeechTranscriber |
| `Services/TextCleanupService.swift` | LLM cleanup via FoundationModels |
| `Services/SharedStorageService.swift` | App Group read/write |
| `VoiceDictationKeyboard/KeyboardViewController.swift` | Keyboard extension controller |
| `Shared/Constants/AppGroupIdentifier.swift` | Shared constants |

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

## User Flow (Keyboard Mode)

### Cold Start (First Use)
1. User taps mic in keyboard
2. `SharedState.isHostAppReady() == false`
3. Keyboard opens `voicedictation://` URI
4. Container app initializes: permissions, audio engine, Darwin observers
5. Container sets `SharedState.setHostAppReady(true)` via App Group
6. User returns to original app → keyboard shows ✗/✓ buttons
7. Recording controlled via Darwin notifications

### Warm Start (Subsequent Uses)
1. User taps mic in keyboard
2. `SharedState.isHostAppReady() == true` (read from App Group shared store)
3. Keyboard shows ✗/✓ buttons immediately
4. Keyboard posts `startRecording` Darwin notification
5. Container (running in background) starts recording
6. User speaks → real-time STT in container
7. User taps ✓ → keyboard posts `stopRecording`
8. Container: LLM cleanup → saves to App Group → posts `textReady`
9. Keyboard auto-inserts text via `textDocumentProxy.insertText()`

### Shared Store (App Group UserDefaults)
- `hostAppReady`: Bool - container initialized
- `cleanedText`: String - final text for insertion
- `rawTranscript`: String - pre-cleanup text
- `status`: String - current recording state

## Commands

```bash
# Build (from Xcode or xcodebuild)
xcodebuild -scheme localspeechtotext_keyboard -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Background Audio Configuration

**Container App Info.plist:**
```xml
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
</array>
<key>NSSupportsLiveActivities</key>
<true/>
```

This enables the container app to:
- Continue recording when backgrounded
- Keep audio engine alive for keyboard commands
- Show Live Activities in Dynamic Island

---

## Darwin Notification Protocol

| Notification | Direction | Purpose |
|--------------|-----------|---------|
| `startRecording` | Keyboard → Container | Start recording |
| `stopRecording` | Keyboard → Container | Stop + process audio |
| `cancelRecording` | Keyboard → Container | Discard recording |
| `recordingStarted` | Container → Keyboard | Confirm recording began |
| `textReady` | Container → Keyboard | Text ready, auto-insert |

---

## Bundle Identifiers

| Component | Identifier |
|-----------|------------|
| Container App | `sozodennis.localspeechtotext-keyboard` |
| Keyboard Extension | `sozodennis.localspeechtotext-keyboard.VoiceDictationKeyboard` |
| App Group | `group.sozodennis.voicedictation` |
| URL Scheme | `voicedictation://` |
