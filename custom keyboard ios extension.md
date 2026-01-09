Below is a **clean, developer‑oriented Markdown conversion** of the **four Apple UIKit custom keyboard pages**, rewritten to be **directly useful when building an iOS custom keyboard extension**.  
Content is **condensed, structured, and actionable** (not a verbatim copy), and aligned with Apple’s current UIKit keyboard architecture.

---

# Creating a Custom Keyboard (UIKit)

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

([developer.apple.com](https://developer.apple.com/documentation/uikit/keyboards_and_input/creating_a_custom_keyboard?utm_source=openai))

---

# Configuring a Custom Keyboard Interface

## Layout & View Hierarchy
- UI lives inside `inputView`
- Width is fixed by the system
- Height can be controlled via Auto Layout

## Adjusting Keyboard Height
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

## Best Practices
- Use Auto Layout
- Keep touch targets large
- Place Globe key consistently
- Match system keyboard ergonomics

## Language Handling
- Single keyboard per language **or**
- Dynamically switch using:
```swift
self.primaryLanguage = "en-US"
```

([developer.apple.com](https://developer.apple.com/documentation/uikit/configuring-a-custom-keyboard-interface?utm_source=openai))

---

# Configuring Open Access for a Custom Keyboard

## What Is Open Access?
Open Access expands the keyboard sandbox to allow:
- Network requests
- Shared App Group containers
- UserDefaults sharing

## Enabling Open Access
In the keyboard extension’s `Info.plist`:
```xml
<key>RequestsOpenAccess</key>
<true/>
```

## User Experience
- Users must explicitly approve
- iOS shows a privacy warning
- Required for:
  - Analytics
  - Cloud sync
  - AI / prediction engines

## Security Implications
- Apple expects clear disclosure
- Some apps (banking, HIPAA) may block your keyboard

([developer.apple.com](https://developer.apple.com/documentation/uikit/configuring-open-access-for-a-custom-keyboard?utm_source=openai))

---

# Handling Text Interactions in Custom Keyboards

## UITextDocumentProxy
All text interaction happens through:
```swift
let proxy = textDocumentProxy
proxy.insertText("Hello")
proxy.deleteBackward()
```

## Supported Actions
- Insert text
- Delete characters
- Read limited context:
```swift
proxy.documentContextBeforeInput
proxy.documentContextAfterInput
```

## Autocorrection & Suggestions
- Access system lexicon via `UILexicon`
- Can combine with custom dictionaries
- No inline suggestion UI near cursor

## Limitations
- No direct text selection
- No access to edit menus (Copy/Paste)

([developer.apple.com](https://developer.apple.com/documentation/uikit/handling-text-interactions-in-custom-keyboards?utm_source=openai))

---

## Recommended Next Steps
- Add SwiftUI‑based layouts inside `UIInputViewController`
- Implement haptics & sound feedback
- Build a settings screen in the containing app
- Validate App Store privacy expectations

If you want, I can next:
- Convert this into a **starter keyboard template**
- Provide a **minimal Swift + SwiftUI keyboard example**
- Create a **checklist for App Store approval**