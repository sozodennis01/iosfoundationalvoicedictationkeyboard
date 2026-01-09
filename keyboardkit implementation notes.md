# KeyboardKit Keyboard-Based Dictation Implementation Notes (Reference Only)

> **NOTE:** This is from a CUSTOM paid KeyboardKit solution which I do NOT use. This is reference material only for understanding dictation patterns. DO NOT use these code references directly.

## Overview

KeyboardKit is a commercial iOS keyboard framework. **This document focuses exclusively on the keyboard-based dictation flow** (`Dictation.DictationMethod.keyboard`) - a BETA feature where dictation is *started* in the main app but *performed* within the keyboard extension. The standard app-based dictation method is mentioned only for context where it differs.

---

## Core Keyboard-Based Dictation Flow

Since keyboard extensions cannot directly access the microphone, KeyboardKit's keyboard-based dictation uses this unique flow:

1. **Initiation**: Keyboard extension opens main app via URL scheme
2. **Setup**: Main app handles authorization, locale detection, and initial setup
3. **Navigation Back**: App navigates back to keyboard extension
4. **Speech Recognition**: Keyboard extension performs live speech recognition using speech recognizer
5. **Text Insertion**: Recognized text is inserted directly via `textDocumentProxy`

---

## Key Architectural Concepts

### Core Requirements for Keyboard-Based Dictation

**Background Audio Mode** (Critical for keyboard-based dictation):
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```
This keeps speech recognition alive when the keyboard extension is active and the main app moves to background.


### 2. Navigation Flow (Keyboard-Based Dictation)

The unique keyboard-based flow requires sophisticated navigation:

**Forward Navigation**: Keyboard → App
- Keyboard extension triggers `KeyboardAction.dictation` action
- Opens main app via deep link (e.g., `<SCHEME>dictation`)
- App handles authorization and locale detection
- App prepares speech recognizer and audio session

**Return Navigation**: App → Keyboard
- App identifies host application bundle ID (`KeyboardInputViewController.hostApplicationBundleId`)
- Navigates back to keyboard extension (now running speech recognition)
- Falls back to manual navigation if host app is unknown

### 3. Speech Recognition Within Keyboard Extension

Once back in the keyboard extension:
- Speech recognition occurs live within the extension (not the main app)
- Uses `DictationSpeechRecognizer` protocol (decoupled from Speech framework)
- Audio buffers are processed via `setupAudioEngineBuffer(_:)`
- Results are inserted directly via `textDocumentProxy`

---

## Dictation Setup Guide (KeyboardKit's Approach)

### Step 1: Required Permissions (Info.plist)

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Describe why you need microphone access.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Describe why you need speech recognition.</string>
```

For keyboard-based dictation, also add background audio:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### Step 2: App Group Setup

Share data between app and keyboard extension using an App Group (e.g., `group.com.example.keyboard`).

### Step 3: URL Scheme

Set up a deep link URL scheme (e.g., `myapp://`):

```swift
KeyboardApp(..., deepLinks: .init(app: "myapp://"))
```

KeyboardKit uses `<SCHEME>dictation` as the default dictation deep link.

### Step 4: Speech Recognizer Protocol

KeyboardKit uses a `DictationSpeechRecognizer` protocol to decouple from the Speech framework.

**Example Implementation** (using Apple's Speech framework):

```swift
import KeyboardKit
import Speech

public extension DictationSpeechRecognizer where Self == StandardSpeechRecognizer {
    static var standard: Self { .init() }
}

public class StandardSpeechRecognizer: DictationSpeechRecognizer {
    public init() {}

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var speechRecognizerTask: SFSpeechRecognitionTask?

    private typealias Err = Dictation.ServiceError

    public var authorizationStatus: Dictation.AuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus().keyboardDictationStatus
    }

    public var supportedLocales: [Locale] {
        Array(SFSpeechRecognizer.supportedLocales())
    }

    public func requestDictationAuthorization() async throws -> Dictation.AuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status.keyboardDictationStatus)
            }
        }
    }

    public func resetDictationResult() async throws {}

    public func startDictation(
        with locale: Locale,
        resultHandler: ((Dictation.SpeechRecognizerResult) -> Void)?
    ) async throws {
        recognizer = SFSpeechRecognizer(locale: locale)
        guard let recognizer else { throw Err.missingSpeechRecognizer }
        request = SFSpeechAudioBufferRecognitionRequest()
        request?.shouldReportPartialResults = true
        guard let request else { throw Err.missingSpeechRecognitionRequest }
        speechRecognizerTask = recognizer.recognitionTask(with: request) {
            let result = Dictation.SpeechRecognizerResult(
                dictatedText: $0?.bestTranscription.formattedString,
                error: $1,
                isFinal: $0?.isFinal ?? true)
            resultHandler?(result)
        }
    }

    public func stopDictation() async throws {
        request?.endAudio()
        request = nil
        speechRecognizerTask?.cancel()
        speechRecognizerTask = nil
    }

    public func setupAudioEngineBuffer(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }
}
```

**Supported Locales:** Arabic, Cantonese, Catalan, Chinese (multiple variants), Croatian, Czech, Danish, Dutch, English (multiple variants), Finnish, French, German, Greek, Hebrew, Hindi, Hungarian, Indonesian, Italian, Japanese, Korean, Malay, Norwegian, Polish, Portuguese, Romanian, Russian, Shanghainese, Slovak, Spanish (multiple variants), Swedish, Thai, Turkish, Ukrainian, Vietnamese

### Step 5: Keyboard Extension Setup

Set up the keyboard extension with the App Group and deep links:

```swift
KeyboardApp(...,
    appGroupId: "group.com.example.keyboard",
    deepLinks: .init(app: "myapp://"))
```


### Step 6: Main Application Setup

Apply the dictation view modifier to handle the keyboard-to-app transition:

```swift
struct ContentView: View {
    @Environment(\.openURL) var openURL
    @EnvironmentObject var dictationContext: DictationContext
    @EnvironmentObject var keyboardContext: KeyboardContext

    var body: some View {
        Text("Insert app here :)")
            .keyboardDictation(
                speechRecognizer: .standard,
                dictationMethod: .keyboard  // Explicitly set keyboard-based dictation
            )
    }
}
```

### Step 7: Dictation Initiation and Flow

The flow begins in the keyboard extension:
- Keyboard triggers `KeyboardAction.dictation` action
- Keyboard opens app via deep link (`<SCHEME>dictation`)
- App handles authorization and initial setup
- App automatically navigates back to keyboard extension
- Keyboard extension performs the actual speech recognition

### Step 8: Processing Results in Keyboard Extension

Recognition results are handled within the keyboard extension:
- Speech recognition occurs via `DictationSpeechRecognizer` protocol
- Audio processing through `setupAudioEngineBuffer(_:)`
- Text insertion via `keyboardContext.textDocumentProxy`
- No manual navigation required - process happens seamlessly in extension

---

## Key Differences: Keyboard vs App-Based Dictation

| Aspect | App-Based Dictation | Keyboard-Based Dictation |
|--------|-------------------|-------------------------|
| **Where recognition happens** | Main app | Keyboard extension |
| **Background audio required** | No | **Yes** - keeps recognition alive |
| **Result flow** | App → Keyboard (via App Group) | Direct to `textDocumentProxy` |
| **Navigation complexity** | Simple (app stays foreground) | Complex (keyboard ↔ app ↔ keyboard) |
| **Host app tracking** | Less critical | Essential for navigation |
| **User experience** | Progress view in app | Seamless in keyboard extension |

**Why keyboard-based dictation is different:** The keyboard extension isolates speech recognition from the main app, requiring background audio permissions and sophisticated navigation, but provides seamless text insertion without leaving the input context.

---

## Key Architectural Components for Keyboard-Based Dictation

### Context & Settings

- **`KeyboardContext`** - Observable keyboard state, includes `textDocumentProxy` reference
- **`KeyboardSettings`** - Auto-persisted settings (locales, autocomplete, etc.)
- **`DictationContext`** - Observable dictation state and settings
- **`DictationSettings`** - Dictation method, silence limit, etc.

### Services

- **`DictationService`** - Protocol for performing dictation from app or keyboard
- **`DictationSpeechRecognizer`** - Protocol for speech recognition implementation
- **`Dictation.StandardDictationService`** - KeyboardKit Pro's standard implementation
- **`Dictation.VolumeRecorder`** - Records microphone volume during dictation
- **`Dictation.StandardVolumeRecorder`** - Standard volume recorder implementation

### Views

- **`Dictation.ProgressView`** - Shows and handles ongoing dictation
- **`Dictation.VolumeVisualizer`** - Renders volume data from recorder
- **`Dictation.Indicator`** - Visual indicator for dictation state
- **`Dictation.SettingsScreen`** - Manages dictation settings

### Data Types

- **`Dictation.AuthorizationStatus`** - Microphone/speech authorization state
- **`Dictation.DictationMethod`** - `.app` vs `.keyboard` dictation
- **`Dictation.DictationState`** - Current dictation state (idle, active, etc.)
- **`Dictation.SpeechRecognizerResult`** - Result from speech recognition

---

## Key Keyboard-Based Dictation Insights

### Essential Technical Requirements
1. **Background audio is critical** - Required for speech recognition when extension is active
2. **Sophisticated navigation** - Complex app/extension transitions with host app tracking
3. **Direct text insertion** - Results go straight to `textDocumentProxy` (no App Group transfer)

### Key Architectural Patterns
4. **Decoupled speech recognition** - `DictationSpeechRecognizer` protocol enables extensibility
5. **Smart host app identification** - Essential for returning to the correct app context
6. **Seamless user experience** - Recognition happens in extension without leaving input focus

### Communication & State Management
7. **URL scheme navigation** - Deep links trigger app-to-keyboard transitions
8. **Shared settings sync** - Locale and preferences auto-sync between app and extension
9. **Live audio buffering** - `setupAudioEngineBuffer()` processes continuous speech input

### Navigation & State Management
- **`KeyboardInputViewController.hostApplicationBundleId`** - Tracks originating app for return navigation
- **`KeyboardSettings.dictionary`** - Shared settings store between app and extension
- **URL Scheme Deep Links** - Handle `<SCHEME>dictation` navigation

### Extension-Specific Requirements
- **Background Audio Permissions** - Essential for keeping recognition alive in extension
- **App Group Communication** - Data sharing between extension and main app
- **`KeyboardContext.textDocumentProxy`** - Direct text insertion interface

---

## Notes on This Implementation

This is a **paid commercial solution** (KeyboardKit Pro) that provides:
- Pre-built dictation service
- Speech recognizer implementations
- UI components and visualizations
- Settings screens
- Host app identification
- Volume recording and visualization

For our implementation, we're using native Apple APIs directly instead of this framework.
