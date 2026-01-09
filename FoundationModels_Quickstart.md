# iOS Foundation Models framework (Apple Intelligence) — Practical Quickstart

> Target: iOS 26 / iPadOS 26 / macOS 26 / visionOS 26 (Apple Intelligence–compatible devices)

## 0) What this is
The **Foundation Models** framework gives you a Swift-native API to call Apple’s **on-device** large language model (LLM) used by Apple Intelligence. The model can run **offline** when available and Apple Intelligence is enabled.

**Docs:** https://developer.apple.com/documentation/FoundationModels

---

## 1) Add the framework
1. In Xcode, set your deployment target to **iOS 26.0+** (or the platform equivalent).
2. Import in the files where you call the model:

```swift
import FoundationModels
```

---

## 2) Check availability (always do this)
Some devices won't support Apple Intelligence, or the user may have it disabled.

```swift
import FoundationModels

let model = SystemLanguageModel.default

switch model.availability {
case .available:
    // OK to create sessions and generate.
    break
case .unavailable(.deviceNotEligible):
    // Show a fallback UI; consider server-side alternative if you have one.
    break
case .unavailable(.appleIntelligenceNotEnabled):
    // Ask the user to enable Apple Intelligence in Settings.
    break
case .unavailable(.modelNotReady):
    // Retry later; show "warming up" UI.
    break
case .unavailable:
    // Handle other cases conservatively.
    break
@unknown default:
    // Handle future unavailability cases
    break
}
```

**⚠️ Always include `@unknown default`** to handle future enum cases added by Apple.

---

## 3) Basic text generation
A **session** holds conversation state (instructions + transcript/history).

```swift
import FoundationModels

let session = LanguageModelSession()
let response = try await session.respond(to: "Draft 3 itinerary options for Osaka in May.")
print(response.content)
```

---

## 4) Guide the model with instructions
Use instructions to make output more consistent.

```swift
import FoundationModels

let instructions = """
You are a helpful travel planner.
Return concise bullet points.
Always include: duration, cost range, and 1 signature food item.
"""

let session = LanguageModelSession(instructions: instructions)
let response = try await session.respond(to: "Plan a 3-day Osaka trip.")
```

Tip: Prefer concise, testable rules in instructions (format, constraints, tone).

---

## 5) Structured output with `@Generable`
Structured output lets you ask for an actual Swift type instead of free text.

```swift
import FoundationModels

@Generable
struct Itinerary: Codable {
    let title: String
    let description: String
    let days: [DayPlan]

    @Generable
    struct DayPlan: Codable {
        let title: String
        let activities: [Activity]
    }

    @Generable
    struct Activity: Codable {
        let title: String
        let description: String
    }
}

let session = LanguageModelSession(instructions: "Return an itinerary object.")
let prompt = "Create a 3-day itinerary for Kyoto focused on food and temples."
let response = try await session.respond(to: prompt, generating: Itinerary.self)

let itinerary: Itinerary = response.content
```

Notes:
- Add `Codable` when you want easy storage / testing.
- Keep schemas small; large nested schemas can be harder for models.

---

## 6) Build prompts with `Prompt { ... }` (PromptBuilder)
When prompts need logic (conditionals, loops), use the prompt builder.

```swift
import FoundationModels

let kidFriendly = true

let prompt = Prompt {
    "Generate a 3-day itinerary to the Grand Canyon."
    if kidFriendly {
        "Must be kid-friendly."
    }
}

let response = try await session.respond(to: prompt, generating: Itinerary.self)
```

---

## 7) Improve reliability with examples (one-shot / few-shot)
Put a **high-quality example** in the prompt and say “don’t copy the content.”

```swift
let prompt = Prompt {
    "Generate a 3-day itinerary to Tokyo."
    "Here is an example of the desired format (do not copy its content):"
    ItineraryExample.text
}
```

---

## 8) Streaming for responsive UI (+ `PartiallyGenerated`)
For long outputs, stream tokens and render partial structured content.

```swift
import FoundationModels

@MainActor
final class TripVM: ObservableObject {
    @Published var partial: Itinerary.PartiallyGenerated?

    private let session = LanguageModelSession()

    func generate() async throws {
        let stream = session.streamResponse(
            to: "Generate a 3-day itinerary to Tokyo.",
            generating: Itinerary.self,
            includeSchemaInPrompt: false
        )

        for try await update in stream {
            partial = update.content   // Itinerary.PartiallyGenerated
        }
    }
}
```

In SwiftUI, unwrap optional fields as they arrive:
```swift
if let title = partial?.title { Text(title) }
```

---

## 9) Tool calling (ground the model in your app’s data)
Tool calling lets the model call your code to fetch **trusted facts** (MapKit results, user data, etc.).

### 9.1 Define a tool
```swift
import FoundationModels

struct FindPointsOfInterestTool: Tool {
    let name = "findPointsOfInterest"
    let description = "Finds points of interest for a landmark."
    let landmarkName: String

    @Generable
    struct Arguments {
        @Guide(description: "Type of business to look up.")
        let category: Category
    }

    @Generable
    enum Category: String, CaseIterable {
        case hotel, restaurant
    }

    func call(arguments: Arguments) async throws -> String {
        // Replace with real data: MapKit search, local database, API, etc.
        let results = ["Example A", "Example B", "Example C"]
        return "In \(landmarkName): \(results.joined(separator: ", "))"
    }
}
```

### 9.2 Provide tools to the session
```swift
let tool = FindPointsOfInterestTool(landmarkName: "Grand Canyon")

let instructions = Instructions {
    "You are an itinerary planner."
    "Always use the 'findPointsOfInterest' tool for hotels and restaurants."
}

let session = LanguageModelSession(
    tools: [tool],
    instructions: instructions
)

let prompt = Prompt { "Generate a 3-day itinerary to Grand Canyon." }
let response = try await session.respond(to: prompt, generating: Itinerary.self)
```

---

## 10) Reduce “time to first token” with prewarming
```swift
session.prewarm()
```

Call prewarm when the user opens the relevant screen (and the model is available).

---

## 11) Practical debugging + testing
- **Log prompts** and model outputs during development.
- Prefer **structured output** for anything you need to render in UI.
- Use tool calling to avoid hallucinated "facts" (addresses, prices, hours).
- Keep user-visible copy honest: show when something is model-generated.

---

## 12) Complete error handling pattern

Here's a production-ready pattern that checks availability and handles errors:

```swift
import FoundationModels

enum LLMError: LocalizedError {
    case deviceNotEligible
    case appleIntelligenceDisabled
    case modelNotReady
    case modelUnavailable
    case processingFailed(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotEligible:
            return "This device does not support Apple Intelligence"
        case .appleIntelligenceDisabled:
            return "Please enable Apple Intelligence in Settings"
        case .modelNotReady:
            return "Language model is still loading, please try again"
        case .modelUnavailable:
            return "Language model is unavailable"
        case .processingFailed(let details):
            return "Processing failed: \(details)"
        }
    }
}

func processWithLLM(_ text: String) async throws -> String {
    // 1. Check availability first
    let model = SystemLanguageModel.default
    switch model.availability {
    case .available:
        break
    case .unavailable(.deviceNotEligible):
        throw LLMError.deviceNotEligible
    case .unavailable(.appleIntelligenceNotEnabled):
        throw LLMError.appleIntelligenceDisabled
    case .unavailable(.modelNotReady):
        throw LLMError.modelNotReady
    case .unavailable:
        throw LLMError.modelUnavailable
    @unknown default:
        throw LLMError.modelUnavailable
    }

    // 2. Create session and process
    let session = LanguageModelSession()
    do {
        let response = try await session.respond(to: text)
        return response.content
    } catch {
        throw LLMError.processingFailed(error.localizedDescription)
    }
}
```

---

## 13) Common gotchas

**Session initialization:**
- Only create `LanguageModelSession()` after confirming `.available` status
- Sessions can be reused for multi-turn conversations

**Response content:**
- `response.content` is a `String` for basic text generation
- For structured output with `@Generable`, it returns the actual Swift type

**Cold start latency:**
- First call may take longer as model loads
- Use `session.prewarm()` to reduce perceived latency
- Show loading UI to set user expectations

---

## References (Apple)
- Framework overview: https://developer.apple.com/documentation/FoundationModels
- Code-along instructions (runnable snippets): https://developer.apple.com/events/resources/code-along-205/
- Apple Intelligence “What’s New”: https://developer.apple.com/apple-intelligence/whats-new/
