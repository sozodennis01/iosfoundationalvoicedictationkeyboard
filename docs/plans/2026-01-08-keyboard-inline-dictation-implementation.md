# Keyboard Inline Dictation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add mic button to keyboard extension that performs speech recognition and text cleanup inline without bouncing to host app.

**Architecture:** Create lightweight KeyboardSpeechService and KeyboardCleanupService in the keyboard extension folder. Add mic button to KeyboardView that hides keyboard during recording/processing and shows full-screen recording UI. Insert cleaned text via textDocumentProxy.

**Tech Stack:** Swift, SwiftUI, iOS 26 SpeechTranscriber, FoundationModels (Apple Intelligence), AVFoundation

**Design Reference:** See `docs/plans/2026-01-08-keyboard-inline-dictation-design.md`

---

## Task 1: Create KeyboardSpeechService (Parallelizable)

**Files:**
- Create: `VoiceDictationKeyboard/KeyboardSpeechService.swift`

**Step 1: Create service file with basic structure**

Create `VoiceDictationKeyboard/KeyboardSpeechService.swift`:

```swift
//
//  KeyboardSpeechService.swift
//  VoiceDictationKeyboard
//
//  Created by Claude on 1/8/26.
//

import Foundation
import Speech
import AVFoundation

@available(iOS 26.0, *)
@MainActor
class KeyboardSpeechService: ObservableObject {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var audioEngine: AVAudioEngine?
    private var currentTranscript = ""

    var hasPermission: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized &&
        AVAudioApplication.shared.recordPermission == .granted
    }

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechGranted else { return false }

        // Request microphone permission
        let micGranted = await AVAudioApplication.requestRecordPermission()

        return speechGranted && micGranted
    }

    func startRecording() async throws {
        // TODO: Implementation
    }

    func stopRecording() -> String {
        // TODO: Implementation
        return currentTranscript
    }
}
```

**Step 2: Implement startRecording method**

Add implementation to `startRecording()`:

```swift
func startRecording() async throws {
    // Reset state
    currentTranscript = ""

    // Create transcriber
    transcriber = SpeechTranscriber(
        locale: Locale.current,
        transcriptionOptions: [],
        reportingOptions: [.volatileResults],
        attributeOptions: []
    )

    guard let transcriber = transcriber else {
        throw NSError(domain: "KeyboardSpeechService", code: 1,
                     userInfo: [NSLocalizedDescriptionKey: "Failed to create transcriber"])
    }

    // Create analyzer
    analyzer = SpeechAnalyzer(modules: [transcriber])

    // Get best audio format
    let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])

    // Create input stream
    let (inputSequence, builder) = AsyncStream<AnalyzerInput>.makeStream()
    self.inputBuilder = builder

    // Start analyzer
    Task {
        try await analyzer?.start(inputSequence: inputSequence)
    }

    // Consume results
    Task {
        do {
            for try await result in transcriber.results {
                let text = String(result.text.characters)
                await MainActor.run {
                    self.currentTranscript = text
                }
            }
        } catch {
            print("Transcription error: \(error)")
        }
    }

    // Set up audio engine
    audioEngine = AVAudioEngine()
    let inputNode = audioEngine!.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
        self?.inputBuilder?.yield(AnalyzerInput(buffer: buffer))
    }

    try audioEngine!.start()
}
```

**Step 3: Implement stopRecording method**

Replace `stopRecording()` implementation:

```swift
func stopRecording() -> String {
    // Stop audio engine
    audioEngine?.stop()
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine = nil

    // Finish input stream
    inputBuilder?.finish()
    inputBuilder = nil

    // Clean up analyzer and transcriber
    analyzer = nil
    transcriber = nil

    return currentTranscript
}
```

**Step 4: Add to Xcode target**

1. Open `localspeechtotext_keyboard.xcodeproj` in Xcode
2. Select `KeyboardSpeechService.swift` in Project Navigator
3. In File Inspector (right sidebar), check target membership for `VoiceDictationKeyboard`
4. Verify it compiles

**Step 5: Commit**

```bash
git add VoiceDictationKeyboard/KeyboardSpeechService.swift
git commit -m "feat: add KeyboardSpeechService for inline speech recognition

- Lightweight service for keyboard extension
- Uses iOS 26 SpeechTranscriber API
- Handles mic + speech permissions
- Captures audio via AVAudioEngine
- Returns final transcript on stop

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 2: Create KeyboardCleanupService (Parallelizable)

**Files:**
- Create: `VoiceDictationKeyboard/KeyboardCleanupService.swift`

**Step 1: Create service file with structure**

Create `VoiceDictationKeyboard/KeyboardCleanupService.swift`:

```swift
//
//  KeyboardCleanupService.swift
//  VoiceDictationKeyboard
//
//  Created by Claude on 1/8/26.
//

import Foundation
import FoundationModels

@available(iOS 26.0, *)
@MainActor
class KeyboardCleanupService: ObservableObject {
    enum CleanupError: LocalizedError {
        case modelUnavailable
        case cleanupFailed

        var errorDescription: String? {
            switch self {
            case .modelUnavailable:
                return "Apple Intelligence is not available on this device"
            case .cleanupFailed:
                return "Text cleanup failed"
            }
        }
    }

    func cleanupText(_ rawText: String) async throws -> String {
        // TODO: Implementation
        return rawText
    }
}
```

**Step 2: Implement cleanupText method**

Replace `cleanupText()` implementation:

```swift
func cleanupText(_ rawText: String) async throws -> String {
    guard !rawText.isEmpty else {
        return rawText
    }

    // Check model availability
    let model = SystemLanguageModel.default

    switch model.availability {
    case .available:
        break
    case .unavailable(.deviceNotEligible),
         .unavailable(.appleIntelligenceNotEnabled),
         .unavailable(.modelNotReady),
         .unavailable:
        // Fall back to raw text if model unavailable
        throw CleanupError.modelUnavailable
    @unknown default:
        throw CleanupError.modelUnavailable
    }

    // Create session with cleanup instructions
    let instructions = """
    You are a text cleanup assistant. Your job is to fix punctuation, \
    capitalization, and remove filler words (um, uh, like, you know).

    Output only the cleaned text with no extra commentary or explanations.
    Do not add content that wasn't spoken.
    """

    let session = LanguageModelSession(instructions: instructions)

    do {
        let response = try await session.respond(to: rawText)
        let cleanedText = response.content

        // If cleanup returns empty, fall back to raw
        return cleanedText.isEmpty ? rawText : cleanedText
    } catch {
        throw CleanupError.cleanupFailed
    }
}
```

**Step 3: Add to Xcode target**

1. Open `localspeechtotext_keyboard.xcodeproj` in Xcode
2. Select `KeyboardCleanupService.swift` in Project Navigator
3. In File Inspector, check target membership for `VoiceDictationKeyboard`
4. Verify it compiles

**Step 4: Commit**

```bash
git add VoiceDictationKeyboard/KeyboardCleanupService.swift
git commit -m "feat: add KeyboardCleanupService for text cleanup

- Lightweight service for keyboard extension
- Uses FoundationModels (Apple Intelligence)
- Checks model availability
- Falls back to raw text if unavailable
- Returns cleaned text or throws error

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 3: Update KeyboardView with Mic Button UI (Depends on Tasks 1 & 2)

**Files:**
- Modify: `VoiceDictationKeyboard/KeyboardView.swift`

**Step 1: Add state properties and services**

Add to top of `KeyboardView` struct (after existing properties):

```swift
@StateObject private var speechService = KeyboardSpeechService()
@StateObject private var cleanupService = KeyboardCleanupService()

@State private var isRecording = false
@State private var isProcessing = false
@State private var errorMessage: String?
```

**Step 2: Add mic button to layout**

Modify `body` to add top bar with mic button before keyboard layout:

```swift
var body: some View {
    VStack(spacing: 0) {
        // Top bar with mic button
        HStack {
            Spacer()

            Button(action: handleMicButtonTap) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 20))
                    .foregroundColor(isRecording ? .white : .gray)
                    .frame(width: 44, height: 44)
                    .background(isRecording ? Color.red : Color(.systemGray5))
                    .cornerRadius(8)
                    .scaleEffect(isRecording ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
            }
            .disabled(isProcessing)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))

        // Error message banner
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .onTapGesture {
                    self.errorMessage = nil
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.errorMessage = nil
                    }
                }
        }

        // Existing keyboard layout (only show when not recording/processing)
        if !isRecording && !isProcessing {
            VStack(spacing: 8) {
                // ... existing keyboard layout code ...
            }
            .padding(.horizontal, 3)
            .padding(.vertical, 8)
        }
    }
    .background(Color(.systemGray6))
}
```

**Step 3: Add recording UI overlay**

Add after the main `VStack` in `body`:

```swift
// Recording UI (full screen overlay)
if isRecording {
    VStack(spacing: 20) {
        Spacer()

        Circle()
            .fill(Color.red)
            .frame(width: 100, height: 100)
            .overlay(
                Image(systemName: "mic.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            )
            .scaleEffect(isRecording ? 1.2 : 1.0)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)

        Text("Recording...")
            .font(.title2)
            .foregroundColor(.primary)

        Text("Tap to stop")
            .font(.subheadline)
            .foregroundColor(.secondary)

        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGray6))
    .onTapGesture {
        handleMicButtonTap()
    }
}

// Processing UI (full screen overlay)
if isProcessing {
    VStack(spacing: 20) {
        Spacer()

        ProgressView()
            .scaleEffect(2)

        Text("Processing...")
            .font(.title2)
            .foregroundColor(.primary)

        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGray6))
}
```

**Step 4: Commit UI changes**

```bash
git add VoiceDictationKeyboard/KeyboardView.swift
git commit -m "feat: add mic button and recording UI to keyboard

- Add mic button in top-right corner
- Add state management for recording/processing
- Add full-screen recording UI overlay
- Add processing UI overlay
- Add error message banner

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 4: Implement Mic Button Logic (Depends on Task 3)

**Files:**
- Modify: `VoiceDictationKeyboard/KeyboardView.swift`

**Step 1: Add mic button tap handler**

Add method to `KeyboardView`:

```swift
private func handleMicButtonTap() {
    if isRecording {
        stopRecording()
    } else {
        startRecording()
    }
}
```

**Step 2: Implement startRecording**

Add method:

```swift
private func startRecording() {
    Task {
        // Check permissions
        var hasPermission = speechService.hasPermission
        if !hasPermission {
            hasPermission = await speechService.requestPermissions()
        }

        guard hasPermission else {
            await MainActor.run {
                errorMessage = "Microphone and speech recognition access required - enable in Settings"
            }
            return
        }

        // Start recording
        do {
            try await speechService.startRecording()
            await MainActor.run {
                isRecording = true
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to start recording: \(error.localizedDescription)"
            }
        }
    }
}
```

**Step 3: Implement stopRecording**

Add method:

```swift
private func stopRecording() {
    isRecording = false

    // Get final transcript
    let transcript = speechService.stopRecording()

    guard !transcript.isEmpty else {
        errorMessage = "No speech detected"
        return
    }

    // Process transcript
    processTranscript(transcript)
}
```

**Step 4: Implement processTranscript**

Add method:

```swift
private func processTranscript(_ rawText: String) {
    Task {
        await MainActor.run {
            isProcessing = true
        }

        do {
            // Clean up text
            let cleanedText = try await cleanupService.cleanupText(rawText)

            await MainActor.run {
                isProcessing = false

                // Insert cleaned text
                textDocumentProxy.insertText(cleanedText)
            }
        } catch {
            // Fall back to raw text on error
            await MainActor.run {
                isProcessing = false

                if error.localizedDescription.contains("unavailable") {
                    errorMessage = "Apple Intelligence unavailable - inserted raw text"
                    textDocumentProxy.insertText(rawText)
                } else {
                    errorMessage = "Processing failed: \(error.localizedDescription)"
                    textDocumentProxy.insertText(rawText)
                }
            }
        }
    }
}
```

**Step 5: Commit logic implementation**

```bash
git add VoiceDictationKeyboard/KeyboardView.swift
git commit -m "feat: implement mic button recording and processing logic

- Handle mic button tap (start/stop)
- Check and request permissions
- Start/stop recording via KeyboardSpeechService
- Process transcript with KeyboardCleanupService
- Insert cleaned text via textDocumentProxy
- Handle errors with fallback to raw text

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 5: Enable Microphone Access in Keyboard Extension (Required)

**Files:**
- Modify: `VoiceDictationKeyboard/Info.plist` (in Xcode)
- Modify: Keyboard extension target settings

**Step 1: Add usage descriptions to Info.plist**

1. Open `localspeechtotext_keyboard.xcodeproj` in Xcode
2. Select `VoiceDictationKeyboard` folder in Project Navigator
3. Find `Info.plist` (or right-click VoiceDictationKeyboard target → "Show File Inspector")
4. Add the following keys:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Voice dictation requires microphone access to transcribe your speech.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Voice dictation uses speech recognition to convert your speech to text.</string>
```

**Step 2: Enable RequestsOpenAccess**

1. Select the project in Project Navigator
2. Select `VoiceDictationKeyboard` target
3. Go to Info tab
4. Under "Custom iOS Target Properties", add:
   - Key: `RequestsOpenAccess`
   - Type: Boolean
   - Value: YES

Or add to Info.plist:
```xml
<key>RequestsOpenAccess</key>
<true/>
```

**Step 3: Verify entitlements**

1. Select `VoiceDictationKeyboard` target
2. Go to Signing & Capabilities tab
3. Verify App Groups capability is present with `group.sozodennis.voicedictation`
4. Build the project to verify no errors

**Step 4: Commit configuration changes**

```bash
git add VoiceDictationKeyboard/Info.plist localspeechtotext_keyboard.xcodeproj
git commit -m "feat: enable microphone access for keyboard extension

- Add microphone usage description
- Add speech recognition usage description
- Enable RequestsOpenAccess for keyboard extension

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Task 6: Build and Test

**Files:**
- All previously created/modified files

**Step 1: Build the project**

```bash
xcodebuild -scheme VoiceDictationKeyboard -destination 'platform=iOS Simulator,name=iPhone 17' clean build
```

Expected: Build succeeds with no errors

**Step 2: Run on device (required for testing)**

Note: Keyboard extensions and microphone access require a real iOS device. Simulators cannot test this functionality.

1. Connect iOS device (iPhone with iOS 26+)
2. In Xcode, select your device as destination
3. Run the app (Cmd+R)
4. Go to Settings → General → Keyboard → Keyboards → Add New Keyboard
5. Select "VoiceDictation"
6. Enable "Allow Full Access" (required for microphone)

**Step 3: Manual testing checklist**

Test in any app (Notes, Messages, etc.):
- [ ] Tap mic button → permission prompt appears
- [ ] Grant permissions → recording starts, keyboard hides
- [ ] Speak some text → recording UI visible
- [ ] Tap to stop → processing UI appears
- [ ] Processing completes → text inserted, keyboard returns
- [ ] Mic button accessible again

Error cases:
- [ ] Deny permissions → error message shown
- [ ] No speech → "No speech detected" message
- [ ] Apple Intelligence unavailable → raw text inserted with message

**Step 4: Document findings**

Create test notes in `docs/testing/keyboard-inline-dictation-manual-tests.md`:

```markdown
# Keyboard Inline Dictation Manual Tests

**Date**: 2026-01-08
**Device**: [Device model and iOS version]
**Build**: [Commit hash]

## Test Results

### Happy Path
- Permission request: [PASS/FAIL - notes]
- Recording UI: [PASS/FAIL - notes]
- Speech recognition: [PASS/FAIL - notes]
- Text cleanup: [PASS/FAIL - notes]
- Text insertion: [PASS/FAIL - notes]

### Error Handling
- Permission denied: [PASS/FAIL - notes]
- No speech detected: [PASS/FAIL - notes]
- Apple Intelligence unavailable: [PASS/FAIL - notes]

## Issues Found
[List any bugs or issues]

## Notes
[Any additional observations]
```

**Step 5: Commit test results**

```bash
git add docs/testing/keyboard-inline-dictation-manual-tests.md
git commit -m "docs: add manual testing results for keyboard inline dictation

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
```

---

## Success Criteria

✅ KeyboardSpeechService successfully records audio and returns transcript
✅ KeyboardCleanupService cleans up text using FoundationModels
✅ Mic button UI works with proper state transitions
✅ Keyboard hides during recording/processing
✅ Error handling works with clear messages
✅ Permissions requested and handled correctly
✅ Text inserted into any app via keyboard
✅ Project builds without errors

## Notes

- **Real Device Required**: This feature MUST be tested on a physical iOS device with iOS 26+. Simulators cannot access microphone or test keyboard extensions properly.
- **Apple Intelligence**: Text cleanup requires Apple Intelligence to be enabled on device. If unavailable, raw transcript is inserted with a message.
- **Full Access Required**: User must enable "Allow Full Access" in keyboard settings for microphone access.
- **Parallel Execution**: Tasks 1 and 2 can be executed in parallel. Task 3 depends on both. Task 4 depends on Task 3. Tasks 5 and 6 are sequential.
