# QWERTY Keyboard Layout Design

**Date:** 2026-01-08
**Status:** Approved
**Author:** Claude (Brainstorming Session)

## Overview

Add a full QWERTY keyboard layout to the keyboard extension using KeyboardKit library, with a persistent mic button for voice dictation. The keyboard handles standard typing, while voice dictation opens the host app via URL scheme for audio recording.

## Requirements

- Standard QWERTY layout with autocomplete suggestions
- Shift/caps lock state management
- Number and symbol layouts
- Persistent mic button in top-right corner (visible in all layouts)
- Dark mode support
- Coordinated communication with host app for voice dictation

## Architecture

### Library Integration

**KeyboardKit** will be added as Swift Package Manager dependency:
- URL: `https://github.com/KeyboardKit/KeyboardKit`
- Provides pre-built QWERTY layouts with proper key sizing
- Built-in autocomplete suggestion bar using iOS native `UITextChecker`
- Shift/caps lock state management
- Number and symbol layout support

### Component Structure

```
KeyboardViewController.swift (UIKit entry point)
└── KeyboardView.swift (SwiftUI, hosted via UIHostingController)
    ├── CustomKeyboardToolbar (mic button + suggestions)
    ├── KeyboardKit's SystemKeyboard (QWERTY layout)
    └── DictationStateView (overlay for recording states)
```

### File Structure

```
VoiceDictationKeyboard/
├── KeyboardViewController.swift          // UIKit entry point (update)
├── KeyboardView.swift                    // SwiftUI main view (new)
├── KeyboardState.swift                   // State management (new)
├── Components/
│   ├── MicButton.swift                   // Persistent mic button (new)
│   └── DictationStateView.swift          // Listening/processing overlay (new)
```

### KeyboardViewController Integration

Replace minimal implementation with SwiftUI hosting:

```swift
class KeyboardViewController: UIInputViewController {
    private var hostingController: UIHostingController<KeyboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        let keyboardView = KeyboardView(
            textDocumentProxy: textDocumentProxy,
            keyboardContext: self
        )

        hostingController = UIHostingController(rootView: keyboardView)
        // Add hosting controller as child, constrain to full view
    }
}
```

### KeyboardView Structure

```swift
struct KeyboardView: View {
    @StateObject private var state = KeyboardState()

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar: autocomplete suggestions + mic button
            HStack {
                AutocompleteToolbar()  // KeyboardKit built-in
                Spacer()
                MicButton(action: state.startDictation)
                    .padding(.trailing, 8)
            }

            // Main keyboard layout from KeyboardKit
            SystemKeyboard(
                state: keyboardState,
                services: services,
                buttonContent: { $0.view },
                buttonView: { $0.view },
                emojiKeyboard: { $0.view },
                toolbar: { EmptyView() }  // We provide custom toolbar
            )

            // Overlay for dictation states
            if state.showDictationOverlay {
                DictationStateView(state: state.dictationState)
            }
        }
    }
}
```

## App Group Communication Protocol

### Shared Data Models

Extend existing `DictationState` model:

```swift
// Shared/Models/DictationState.swift (update)
enum DictationCommand: String, Codable {
    case armMic           // Keyboard → Host: prepare mic session
    case micReady         // Host → Keyboard: ready to record
    case startRecording   // Keyboard → Host: begin capture
    case stopRecording    // Keyboard → Host: end capture
    case processing       // Host → Keyboard: cleaning text
    case textReady        // Host → Keyboard: text available
    case error            // Host → Keyboard: something failed
}

struct DictationSession: Codable {
    let sessionId: UUID
    var command: DictationCommand
    var timestamp: Date
    var error: String?
}

struct DictationState: Codable {
    var session: DictationSession?
    var cleanedText: String?
    var rawTranscript: String?
}
```

### App Group Keys

```swift
// Shared/Constants/AppGroupIdentifier.swift (update)
enum AppGroupKeys {
    static let currentSession = "currentDictationSession"
    static let cleanedText = "cleanedText"
    static let rawTranscript = "rawTranscript"  // Optional, for debugging
}
```

### Communication Flow

1. **Keyboard taps mic** → writes `{command: .armMic, sessionId: UUID()}`
2. **Keyboard calls** `openURL("voicedictation://start")`
3. **Host app foregrounds** → reads session, initializes audio session, writes `{command: .micReady}`
4. **Host app shows** "Swipe back to continue"
5. **User swipes back** → keyboard polls App Group, sees `.micReady`, shows "Listening" UI
6. **Keyboard auto-sends** `{command: .startRecording}`
7. **Host app (backgrounded)** → polls App Group, sees `.startRecording`, begins recording
8. **User taps stop in keyboard** → writes `{command: .stopRecording}`
9. **Host app processes** → writes `{command: .processing}`, then `{command: .textReady, cleanedText: "..."}`
10. **Keyboard inserts text** → reads `cleanedText`, calls `textDocumentProxy.insertText()`

Both keyboard and host app poll App Group storage to detect state changes. The `sessionId` ensures commands from stale sessions are ignored.

## Background Recording Implementation

### Host App Configuration

Add background audio capability to `Info.plist`:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### Background Recording Service

```swift
// localspeechtotext_keyboard/Services/BackgroundDictationService.swift (new)
class BackgroundDictationService: ObservableObject {
    private let storage = SharedStorageService.shared
    private let speechService = SpeechRecognitionService()
    private let cleanupService = TextCleanupService()

    private var pollingTimer: Timer?
    private var currentSessionId: UUID?

    func startMonitoring() {
        // Poll App Group every 0.5 seconds for commands
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForCommands()
        }
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkForCommands() {
        guard let session = storage.loadCurrentSession() else { return }

        // Ignore stale sessions
        guard currentSessionId == nil || session.sessionId == currentSessionId else { return }

        switch session.command {
        case .armMic:
            handleArmMic(session)
        case .startRecording:
            handleStartRecording(session)
        case .stopRecording:
            handleStopRecording(session)
        default:
            break
        }
    }

    private func handleArmMic(_ session: DictationSession) {
        currentSessionId = session.sessionId

        // Ensure permissions and audio session ready
        Task {
            await speechService.requestPermissions()

            // Write ready state back to App Group
            var updatedSession = session
            updatedSession.command = .micReady
            storage.saveCurrentSession(updatedSession)
        }
    }

    private func handleStartRecording(_ session: DictationSession) {
        Task {
            await speechService.startRecording()
        }
    }

    private func handleStopRecording(_ session: DictationSession) {
        Task {
            let transcript = await speechService.stopRecording()

            // Update state to processing
            var processingSession = session
            processingSession.command = .processing
            storage.saveCurrentSession(processingSession)

            // Clean up text with LLM
            let cleanedText = await cleanupService.cleanup(text: transcript)

            // Write final result
            storage.saveCleanedText(cleanedText)
            var completeSession = session
            completeSession.command = .textReady
            storage.saveCurrentSession(completeSession)

            currentSessionId = nil  // Reset for next session
        }
    }
}
```

### App Lifecycle Integration

```swift
// localspeechtotext_keyboard/localspeechtotext_keyboardApp.swift (update)
@main
struct VoiceDictationApp: App {
    @StateObject private var backgroundService = BackgroundDictationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    backgroundService.startMonitoring()
                }
        }
    }
}
```

The host app continuously polls App Group storage while running (foreground or background with active audio session). When it sees a command, it executes the action and writes the response back.

## Keyboard State Machine

### KeyboardState Manager

```swift
// VoiceDictationKeyboard/KeyboardState.swift (new)
@MainActor
class KeyboardState: ObservableObject {
    @Published var dictationState: DictationUIState = .idle
    @Published var showDictationOverlay: Bool = false

    private let storage = SharedStorageService.shared
    private var pollingTimer: Timer?
    private var currentSessionId: UUID?

    enum DictationUIState {
        case idle                          // Normal keyboard
        case arming                        // "Opening app..."
        case waitingForSwipeBack          // Should never show (user is in host app)
        case listening                     // "Listening..." with stop button
        case processing                    // "Processing..." spinner
        case error(String)                // Error message
    }

    func startDictation() {
        // Create new session
        let sessionId = UUID()
        currentSessionId = sessionId

        let session = DictationSession(
            sessionId: sessionId,
            command: .armMic,
            timestamp: Date()
        )

        storage.saveCurrentSession(session)

        // Open host app
        if let url = URL(string: "voicedictation://start") {
            UIApplication.shared.open(url)
        }

        // Update UI
        dictationState = .arming
        showDictationOverlay = true

        // Start polling for response
        startPolling()
    }

    func stopDictation() {
        guard let sessionId = currentSessionId else { return }

        var session = DictationSession(
            sessionId: sessionId,
            command: .stopRecording,
            timestamp: Date()
        )

        storage.saveCurrentSession(session)
        dictationState = .processing
    }

    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkState()
        }
    }

    private func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    private func checkState() {
        guard let session = storage.loadCurrentSession(),
              session.sessionId == currentSessionId else { return }

        switch session.command {
        case .micReady:
            // User has returned from host app
            dictationState = .listening

            // Auto-send start recording command
            var recordingSession = session
            recordingSession.command = .startRecording
            storage.saveCurrentSession(recordingSession)

        case .processing:
            dictationState = .processing

        case .textReady:
            if let text = storage.loadCleanedText() {
                insertText(text)
            }
            resetState()

        case .error:
            dictationState = .error(session.error ?? "Unknown error")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.resetState()
            }

        default:
            break
        }
    }

    private func insertText(_ text: String) {
        // Called via textDocumentProxy from KeyboardView
        // KeyboardView passes the proxy down to this state object
    }

    private func resetState() {
        stopPolling()
        currentSessionId = nil
        dictationState = .idle
        showDictationOverlay = false

        // Clear App Group data
        storage.clearCurrentSession()
    }
}
```

### DictationStateView (Overlay)

```swift
// VoiceDictationKeyboard/Components/DictationStateView.swift (new)
struct DictationStateView: View {
    let state: KeyboardState.DictationUIState
    let onStop: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                switch state {
                case .arming:
                    ProgressView()
                    Text("Opening app...")

                case .listening:
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                    Text("Listening...")
                    Button("Stop") {
                        onStop()
                    }
                    .buttonStyle(.borderedProminent)

                case .processing:
                    ProgressView()
                    Text("Processing...")

                case .error(let message):
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(message)

                default:
                    EmptyView()
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(16)
        }
    }
}
```

The keyboard polls App Group storage every 0.3 seconds while a dictation session is active. When it sees state changes from the host app, it updates the UI accordingly.

## User Flow

### First-Time Setup Flow

1. User enables keyboard in Settings
2. User switches to VoiceDictation keyboard in any app
3. User taps mic button
4. Host app opens and shows "Apple requires this step to activate microphone"
5. User grants microphone + speech permissions
6. Host app shows "Swipe back to continue"
7. User swipes back to original app
8. Keyboard shows "Listening..." overlay
9. User speaks, taps Stop
10. Keyboard shows "Processing..."
11. Text appears in text field

### Subsequent Dictations

1. User taps mic button
2. Host app briefly appears (already in background)
3. User swipes back immediately
4. Keyboard shows "Listening..." (host app recording in background)
5. User speaks, taps Stop
6. Text inserted

## Implementation Checklist

### Phase 1: KeyboardKit Integration
- [ ] Add KeyboardKit via Swift Package Manager
- [ ] Update `KeyboardViewController.swift` to host SwiftUI view
- [ ] Create `KeyboardView.swift` with KeyboardKit's `SystemKeyboard`
- [ ] Add custom toolbar with autocomplete + mic button
- [ ] Test basic typing functionality

### Phase 2: Shared Models
- [ ] Extend `DictationState` with command enum
- [ ] Add `DictationSession` model with UUID
- [ ] Update `AppGroupKeys` constants
- [ ] Update `SharedStorageService` with session save/load methods

### Phase 3: Background Recording
- [ ] Add `UIBackgroundModes: audio` to host app Info.plist
- [ ] Create `BackgroundDictationService.swift`
- [ ] Implement App Group polling (0.5s interval)
- [ ] Add command handlers (armMic, startRecording, stopRecording)
- [ ] Integrate with app lifecycle

### Phase 4: Keyboard State Management
- [ ] Create `KeyboardState.swift` with state machine
- [ ] Implement App Group polling in keyboard (0.3s interval)
- [ ] Add mic button tap → URL scheme → arming flow
- [ ] Create `DictationStateView.swift` overlay
- [ ] Wire up stop button → stopRecording command

### Phase 5: Testing
- [ ] Unit test: DictationSession codable encoding/decoding
- [ ] Unit test: State transitions in KeyboardState
- [ ] Integration test: App Group communication both directions
- [ ] Manual device test: First-time permission flow
- [ ] Manual device test: Subsequent dictation flow
- [ ] Manual device test: Background recording while keyboard visible
- [ ] Test in multiple apps (Messages, Notes, Safari)

### Phase 6: Polish
- [ ] Add haptic feedback on mic button tap
- [ ] Animate listening waveform
- [ ] Handle error cases (permission denied, LLM unavailable, etc.)
- [ ] Add timeout for stale sessions
- [ ] Improve "Swipe back" UI in host app

## Open Questions

None - design approved.

## Notes

- KeyboardKit is an active dependency (check for breaking changes on updates)
- Polling intervals (0.5s host, 0.3s keyboard) are tunable for performance
- Session UUID prevents race conditions from stale App Group data
- Background audio mode keeps host app alive while keyboard is visible
- iOS does not allow automatic return to previous app, hence "swipe back" pattern
