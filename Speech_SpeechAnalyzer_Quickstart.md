# iOS Speech — SpeechAnalyzer & SpeechTranscriber (iOS 26) Quickstart

> Target: iOS 26 / iPadOS 26 / macOS 26 / visionOS 26 (SpeechAnalyzer availability varies by device)

## 0) What’s new in iOS 26
Apple introduced **SpeechAnalyzer**, a Swift-first speech-to-text API designed to support more use cases (including long-form and distant audio). It replaces many use cases that previously relied on `SFSpeechRecognizer`.

**Docs:** https://developer.apple.com/documentation/Speech

**WWDC25 session:** https://developer.apple.com/videos/play/wwdc2025/277/

---

## 1) Add the right privacy keys (Info.plist)
If you capture audio for transcription, you typically need:
- `NSMicrophoneUsageDescription` — why you need the microphone.
- `NSSpeechRecognitionUsageDescription` — why you need speech recognition (especially if any server processing may occur).

Example (Info.plist):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We use the microphone to transcribe your recordings into text.</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>We convert your speech into text to provide transcripts and searchable notes.</string>
```

References:
- `NSMicrophoneUsageDescription`: https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription
- `NSSpeechRecognitionUsageDescription`: https://developer.apple.com/documentation/bundleresources/information-property-list/nsspeechrecognitionusagedescription

---

## 2) Core concepts (mental model)
- `SpeechAnalyzer` manages an **analysis session**.
- You add a module like `SpeechTranscriber` to get speech-to-text results.
- You feed audio in, and read results out using **Swift concurrency** (async sequences / streams).
- Results are correlated using the session's **audio timeline** (timecodes).
- Optionally enable **volatile results** for fast-but-improving live text, then a final stabilized result.

---

## 3) Permission handling (IMPORTANT)

**⚠️ Common mistakes:**
- `SFSpeechRecognizer.authorizationStatus(preset: .dictation)` — DOES NOT EXIST
- `SFSpeechRecognizer.requestAuthorization(preset: .dictation)` — DOES NOT EXIST
- `await SFSpeechRecognizer.requestAuthorization()` — DOES NOT EXIST (it's callback-based)

**✅ Correct pattern:**
```swift
import Speech
import AVFoundation

// Check current authorization status (no parameters!)
let status = SFSpeechRecognizer.authorizationStatus()

// Request speech recognition permission (callback-based, wrap in async)
func requestSpeechPermission() async -> Bool {
    await withCheckedContinuation { continuation in
        SFSpeechRecognizer.requestAuthorization { status in
            continuation.resume(returning: status == .authorized)
        }
    }
}

// Request microphone permission
func requestMicPermission() async -> Bool {
    await AVAudioApplication.requestRecordPermission()
}
```

---

## 4) Ensure model assets are available (AssetInventory)
SpeechTranscriber relies on model assets managed by the system. The WWDC demo uses **AssetInventory** to allocate/deallocate locales.

Pseudocode structure:
```swift
import Speech

let locale = Locale(identifier: "en_US")

// Allocate required model assets (exact APIs may differ by platform / version).
try await AssetInventory.allocate(locale: locale)
// Later, you can deallocate if you need to free space.
await AssetInventory.deallocate(locale: locale)
```

---

## 5) Transcribe an audio file (high-level pattern)
```swift
import Speech

let transcriber = SpeechTranscriber(
    locale: Locale.current,
    transcriptionOptions: [],
    reportingOptions: [.volatileResults],
    attributeOptions: [.audioTimeRange]
)

let analyzer = SpeechAnalyzer(modules: [transcriber])

// Collect results from the transcriber concurrently.
// NOTE: results is a throwing async sequence - use `for try await`
// NOTE: result.text is AttributedString - convert to String
let transcriptTask = Task { () -> String in
    var text = ""
    do {
        for try await result in transcriber.results {
            // result.text is AttributedString, convert to String
            let resultText = String(result.text.characters)
            text += resultText + " "
        }
    } catch {
        // Handle transcription error
    }
    return text
}

// Feed the file into the analyzer.
if let lastSample = try await analyzer.analyzeSequence(from: fileURL) {
    try await analyzer.finalizeAndFinish(through: lastSample)
} else {
    await analyzer.cancelAndFinishNow()
}

let finalText = await transcriptTask.value
```

Notes:
- Use `.volatileResults` only if your UI needs immediate partial text.
- Use `.audioTimeRange` if you want to highlight words during playback.
- **`result.text` is `AttributedString`**, not `String` — use `String(result.text.characters)` to convert.
- **`transcriber.results` throws** — always use `for try await` in a do-catch block.

---

## 6) Live transcription (microphone) — COMPLETE WORKING EXAMPLE

**⚠️ Common mistakes when feeding audio buffers:**
- `analyzer.analyze(buffer)` — DOES NOT EXIST
- `analyzer.append(buffer)` — DOES NOT EXIST
- `analyzer.process(buffer)` — DOES NOT EXIST

**✅ The correct pattern uses `AsyncStream<AnalyzerInput>`:**

```swift
import AVFoundation
import Speech

class LiveTranscriptionService {
    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerFormat: AVAudioFormat?

    func startTranscription(onResult: @escaping (String) -> Void) async throws {
        // 1. Create transcriber with default locale
        let newTranscriber = SpeechTranscriber(
            locale: Locale.current,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        transcriber = newTranscriber

        // 2. Create analyzer with transcriber module
        let newAnalyzer = SpeechAnalyzer(modules: [newTranscriber])
        analyzer = newAnalyzer

        // 3. Get best audio format for the analyzer
        analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [newTranscriber]
        )

        // 4. Create AsyncStream for feeding audio (THIS IS THE KEY!)
        let (inputSequence, inputBuilder) = AsyncStream<AnalyzerInput>.makeStream()
        inputContinuation = inputBuilder

        // 5. Start the analyzer with the input sequence
        Task {
            try await newAnalyzer.start(inputSequence: inputSequence)
        }

        // 6. Consume transcription results
        Task {
            do {
                for try await result in newTranscriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        onResult(text)
                    }
                }
            } catch {
                // Handle error
            }
        }

        // 7. Set up AVAudioEngine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // 8. Install tap to capture audio and feed via continuation
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        // 9. Start audio engine
        try audioEngine.start()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let inputContinuation = inputContinuation else { return }

        // Convert to analyzer format if needed, then yield
        if let analyzerFormat = analyzerFormat,
           let converted = convertBuffer(buffer, to: analyzerFormat) {
            inputContinuation.yield(AnalyzerInput(buffer: converted))
        } else {
            inputContinuation.yield(AnalyzerInput(buffer: buffer))
        }
    }

    private func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard buffer.format != format else { return buffer }
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else { return nil }

        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * format.sampleRate / buffer.format.sampleRate
        )
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCapacity) else {
            return nil
        }

        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        return error == nil ? convertedBuffer : nil
    }

    func stopTranscription() {
        // Finish the input stream (signals end of audio)
        inputContinuation?.finish()
        inputContinuation = nil

        // Stop audio engine
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        transcriber = nil
        analyzer = nil
    }
}
```

**Key points:**
- Use `AsyncStream<AnalyzerInput>.makeStream()` to create input stream and continuation
- Call `analyzer.start(inputSequence:)` to start processing
- Feed buffers via `inputContinuation.yield(AnalyzerInput(buffer:))`
- Call `inputContinuation.finish()` when done
- Convert audio format to match `SpeechAnalyzer.bestAvailableAudioFormat()`

---

## 7) Fallback transcriber (DictationTranscriber)
If `SpeechTranscriber` isn't available for the device/language, iOS 26 also provides `DictationTranscriber` as a fallback that aligns with older dictation behavior.

---

## 8) Notes on legacy `SFSpeechRecognizer`
`SFSpeechRecognizer` still exists (iOS 10+), but SpeechAnalyzer is the modern path in iOS 26 for better long-form and low-latency use cases.

---

## 9) Swift Concurrency gotchas

**❌ Don't use `||` with async calls:**
```swift
// This will NOT compile - async in autoclosure
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

---

## References (Apple)
- Speech docs: https://developer.apple.com/documentation/Speech
- SpeechAnalyzer: https://developer.apple.com/documentation/speech/speechanalyzer
- WWDC25 SpeechAnalyzer session: https://developer.apple.com/videos/play/wwdc2025/277/
- `NSMicrophoneUsageDescription`: https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription
- `NSSpeechRecognitionUsageDescription`: https://developer.apple.com/documentation/bundleresources/information-property-list/nsspeechrecognitionusagedescription
