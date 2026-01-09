# iOS Custom Keyboard Extension Guide

## Overview

A custom keyboard is an **iOS app extension** that replaces the system keyboard across apps. It is implemented using a subclass of `UIInputViewController` and communicates with the host app through a `UITextDocumentProxy`.

## Key Concepts

- Implemented as a **Custom Keyboard Extension target**
- Main controller: `UIInputViewController`
- Text insertion via `textDocumentProxy`
- Must include a **Next Keyboard (🌐)** button
- Runs in a **sandboxed environment**

## Core APIs

```swift
class KeyboardViewController: UIInputViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
```

## Important Constraints

- Cannot access microphone or camera
- Cannot draw outside its view bounds
- Cannot select text directly
- Network access disabled by default

## Setup Steps

1. Create a containing app
2. Add a **Custom Keyboard Extension** target
3. Enable keyboard in **Settings → General → Keyboard**

---

## Configuring the Interface

### Layout & View Hierarchy

- UI lives inside `inputView`
- Width is fixed by the system
- Height can be controlled via Auto Layout

### Adjusting Keyboard Height

```swift
let height = NSLayoutConstraint(
    item: view!,
    attribute: .height,
    relatedBy: .equal,
    toItem: nil,
    attribute: .notAnAttribute,
    multiplier: 1.0,
    constant: 300
)
view.addConstraint(height)
```

### Best Practices

- Use Auto Layout
- Keep touch targets large
- Place Globe key consistently
- Match system keyboard ergonomics

### Language Handling

Single keyboard per language **or** dynamically switch:

```swift
self.primaryLanguage = "en-US"
```

---

## Open Access

### What Is Open Access?

Open Access expands the keyboard sandbox to allow:

- Network requests
- Shared App Group containers
- UserDefaults sharing

### Enabling Open Access

In the keyboard extension's `Info.plist`:

```xml
<key>RequestsOpenAccess</key>
<true/>
```

### User Experience

- Users must explicitly approve
- iOS shows a privacy warning
- Required for: analytics, cloud sync, AI/prediction engines

### Security Implications

- Apple expects clear disclosure
- Some apps (banking, HIPAA) may block your keyboard

---

## Handling Text Interactions

### UITextDocumentProxy

All text interaction happens through:

```swift
let proxy = textDocumentProxy
proxy.insertText("Hello")
proxy.deleteBackward()
```

### Supported Actions

- Insert text
- Delete characters
- Read limited context:

```swift
proxy.documentContextBeforeInput
proxy.documentContextAfterInput
```

### Autocorrection & Suggestions

- Access system lexicon via `UILexicon`
- Can combine with custom dictionaries
- No inline suggestion UI near cursor

### Limitations

- No direct text selection
- No access to edit menus (Copy/Paste)

---

## Microphone Access (Critical Limitation)

### TL;DR

**You cannot record audio from an iOS custom keyboard extension.**

Even with `RequestsOpenAccess` / "Allow Full Access", the extension lacks entitlements to start recording and will fail on real devices.

### What Apple Says

> "Custom keyboards … have no access to the device microphone, so dictation input is not possible."

Source: [App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)

### Common Symptoms

| Environment | Behavior                                        |
|-------------|-------------------------------------------------|
| Simulator   | Permission prompt appears, recording may work   |
| Real Device | Permission prompt may appear, but recording fails |

Console error:

```text
CMSUtility_IsAllowedToStartRecording ... was NOT allowed to start recording because it is an extension and doesn't have entitlements to record audio.
```

### Why This Is Confusing

Developers try all of these and still fail:

- `AVAudioSession.sharedInstance().requestRecordPermission`
- `NSMicrophoneUsageDescription` in Info.plist
- `RequestsOpenAccess = YES` with "Allow Full Access" enabled

The permission prompt can show, but **entitlements** control whether recording actually starts.

---

## Voice Input Workarounds

### Option A: System Dictation (Recommended)

Provide a button: "Use iOS Dictation" with instructions:

> "Tap 🌐 to switch keyboards → choose Apple keyboard → tap 🎤"

- **Pros:** Reliable, no privacy concerns, no hacks
- **Cons:** Requires user to switch keyboards

### Option B: Record in Containing App

1. Keyboard opens containing app
2. App records + performs speech recognition
3. App writes text to **App Group** shared storage
4. User returns, keyboard inserts the text

**Warning:** Opening the containing app from a keyboard is not officially supported. Only Today widgets can use `NSExtensionContext.open(...)`. Keyboards using private APIs risk:

- Breaking across iOS versions
- App Store rejection
- Keyboard dismissal when host app loses focus

### Data Passing Patterns

#### Preferred: App Group

```swift
// Write in app
UserDefaults(suiteName: "group.com.your.app")?.set(text, forKey: "transcription")

// Read in keyboard
let text = UserDefaults(suiteName: "group.com.your.app")?.string(forKey: "transcription")
textDocumentProxy.insertText(text ?? "")
```

#### Fallback: Pasteboard

Not recommended for sensitive text.

### Implementation Checklist

1. **Containing app**: Mic recording + transcription
2. **Shared storage**: App Group
3. **Keyboard UI**: Voice key + Insert transcription key
4. **Privacy**: Clear disclosure, no auto-sending data

### What NOT to Do

- Don't ship private-API "open app" hacks
- Don't assume "Allow Full Access" grants mic recording
- Don't depend on Simulator-only behavior

---

## References

- [Creating a Custom Keyboard](https://developer.apple.com/documentation/uikit/keyboards_and_input/creating_a_custom_keyboard)
- [Configuring a Custom Keyboard Interface](https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface)
- [Configuring Open Access](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard)
- [Handling Text Interactions](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards)
- [App Extension Programming Guide: Custom Keyboard](https://developer.apple.com/library/archive/documentation/General/Conceptual/ExtensibilityPG/CustomKeyboard.html)
- [RequestsOpenAccess Key](https://developer.apple.com/documentation/bundleresources/information-property-list/nsextension/nsextensionattributes/requestsopenaccess)
- [Developer Forums: Recording audio in keyboard extension](https://developer.apple.com/forums/thread/742601)
