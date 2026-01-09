# Keyboard Inline Dictation Design

**Date**: 2026-01-08
**Status**: Approved

## Overview

Add microphone button to the keyboard extension that performs speech recognition and text cleanup inline, without bouncing to the host app via URL schemes.

## Architecture

### Component Structure

- Mic button in top-right corner of `KeyboardView.swift`
- Three states: idle, recording, processing
- Keyboard layout hides during recording/processing, shows full-screen recording UI

### Service Files (New, Lightweight)

Create two new services in `VoiceDictationKeyboard/` folder:

#### KeyboardSpeechService.swift
Simplified speech recognition without App Group or state persistence:
- `startRecording()` - begins audio capture
- `stopRecording()` - ends capture and returns final transcript as String
- `hasPermission` property - checks mic + speech permissions
- `requestPermissions()` - requests permissions if needed

Implementation uses iOS 26 APIs:
- `SpeechTranscriber` with `Locale.current` and `.volatileResults`
- `SpeechAnalyzer` with transcriber module
- `AVAudioEngine` for mic input
- `AsyncStream` to feed audio buffers
- Collect transcript from `transcriber.results` AsyncSequence

#### KeyboardCleanupService.swift
Simplified text cleanup without state tracking:
- `cleanupText(_ rawText: String) async throws -> String`
- Check `SystemLanguageModel.default.availability`
- Use `LanguageModelSession` with cleanup instructions
- Return cleaned text or throw error

### State Management

`KeyboardView` will have:
```swift
@StateObject private var speechService = KeyboardSpeechService()
@StateObject private var cleanupService = KeyboardCleanupService()
@State private var isRecording = false
@State private var isProcessing = false
@State private var errorMessage: String?
```

## UI Layout & Visual States

### Mic Button Placement

New top bar above QWERTY keyboard:
```
┌─────────────────────────────────┐
│                      [🎤] ← mic │
├─────────────────────────────────┤
│ Q W E R T Y U I O P             │
│  A S D F G H J K L              │
│ ⇧ Z X C V B N M ⌫               │
│        [ space ]      [return]  │
└─────────────────────────────────┘
```

### Button States

1. **Idle** (default):
   - Gray mic icon (`mic.fill`)
   - `.systemGray5` background
   - 44x44pt tappable area

2. **Recording** (keyboard hidden, full recording UI shown):
   - Large pulsing red mic icon
   - "Recording..." text
   - "Tap to stop" hint
   - Pulsing scale animation

3. **Processing** (keyboard hidden):
   - Spinner/progress indicator
   - "Processing..." text
   - Disabled state

### Error Display

When `errorMessage != nil`, show red text banner below mic button:
- Tappable to dismiss
- Auto-dismiss after 5 seconds

## Data Flow & User Interaction

### Happy Path

1. **User taps mic button (first time)**
   - Check `speechService.hasPermission`
   - If no permission → request via `speechService.requestPermissions()`
   - If denied → set `errorMessage`, return
   - If granted → call `speechService.startRecording()`
   - Set `isRecording = true`
   - Hide keyboard layout, show recording UI

2. **User speaks**
   - Audio captured continuously
   - Recording UI visible with pulsing animation
   - Transcript building internally

3. **User taps to stop**
   - Call `speechService.stopRecording()` → returns transcript
   - Set `isRecording = false`
   - Set `isProcessing = true`
   - Show processing UI

4. **Text cleanup phase**
   - Call `cleanupService.cleanupText(transcript)`
   - Wait for FoundationModels
   - Set `isProcessing = false`

5. **Insert text**
   - Call `textDocumentProxy.insertText(cleanedText)`
   - Show keyboard layout again
   - Reset to idle

## Error Handling

### Permission Errors

- **Microphone denied**: "Microphone access required - enable in Settings"
- **Speech recognition denied**: "Speech recognition required - enable in Settings"
- Display inline below mic button, auto-dismiss after 5 seconds

### FoundationModels Errors

- **Model unavailable**: Fall back to raw transcript, show "Apple Intelligence unavailable - inserted raw text"
- **Cleanup fails/times out**: Insert raw transcript as fallback

### Recording Errors

- **Audio engine fails**: Show error, reset to idle
- **No speech detected**: Show "No speech detected", don't insert anything

### Edge Cases

- **User switches apps mid-recording**: Stop recording automatically
- **Very long recordings**: No artificial time limit
- **Empty transcript after cleanup**: Insert raw transcript if cleanup returns empty

### State Cleanup

Always reset `isRecording` and `isProcessing` to false after errors.

## Implementation Notes

- Enable `RequestsOpenAccess = YES` in keyboard Info.plist to allow microphone access
- Follow iOS 26 API patterns from CLAUDE.md (avoid common mistakes with SpeechTranscriber)
- Keep services lightweight - no App Group saving, no complex state management
- Test on real device - keyboard extensions behave differently in simulator

## Success Criteria

- User can tap mic button to start recording
- Keyboard disappears during recording, shows clear recording UI
- User can tap to stop recording
- Text is cleaned up and inserted into text field
- Errors are handled gracefully with clear messages
- State never gets stuck in recording or processing
