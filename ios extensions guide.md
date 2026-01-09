# iOS App Extension Essentials

## What Is an App Extension?

- A bundle (ends in `.appex`) embedded inside a containing app
- Users invoke from a host app (or system UI)
- Host sends request → extension handles it → completes/cancels → exits

---

## 1. Choose the Right Extension Point

The extension point determines:

- Which APIs are available
- How certain APIs behave
- Required Info.plist keys and entitlements

**Adding a target:** Xcode → File → New → Target → Application Extension → select template

---

## 2. Default Template Contents

Each extension template includes:

- `Info.plist` (extension configuration)
- Principal class (often a view controller)
- Default UI (if applicable)

---

## 3. Critical Info.plist Keys

The `NSExtension` dictionary must contain:

| Key | Description |
|-----|-------------|
| `NSExtensionPointIdentifier` | Reverse-DNS identifier (e.g., `com.apple.widget-extension`) |
| `NSExtensionPrincipalClass` | Main class the system instantiates |
| `NSExtensionMainStoryboard` | Default storyboard (iOS UI extensions) |
| `NSExtensionAttributes` | Extension-point-specific attributes |

### Capabilities/Entitlements

- Templates may set capabilities by default (e.g., Document Provider includes App Groups)
- Extensions typically inherit access the containing app has been granted

---

## 4. Request/Response Lifecycle

```
User selects extension
    ↓
Host app sends request with context
    ↓
Extension reads inputItems, presents UI
    ↓
User completes or cancels
    ↓
Extension calls:
  - completeRequestReturningItems:completionHandler:
  - cancelRequestWithError:
```

### Getting Inputs

```swift
let context = self.extensionContext
let items = context?.inputItems as? [NSExtensionItem]
// Each item can have: title, text, userInfo, attachments (NSItemProvider)
```

---

## 5. Background Work Rules (iOS)

- Use `NSURLSession` background transfers for long work (upload/download)
- These run out-of-process and continue after extension exits
- **Cannot use other background modes** (VoIP, audio, etc.)
- `UIBackgroundModes` in extension Info.plist → **App Store rejection**

---

## 6. Performance Limits

| Constraint | Guideline |
|------------|-----------|
| Launch time | Well under 1 second; slow = terminated |
| Memory | Lower limits than foreground apps |
| Termination | Aggressive due to memory pressure |
| Main thread | Don't block it |
| GPU | Avoid heavy graphics workloads |

**Rule:** If it's resource-heavy, put it in the app, not the extension.

---

## 7. UI Guidelines

- Simple, single-task focused
- Minimal/fast (avoid extra chrome)

### Icons & Naming

- Icon must match containing app's icon
- Share extension uses containing app icon automatically
- Naming: `<Containing App Name>—<Extension Name>`
- Display name: `CFBundleDisplayName` in extension Info.plist
- Localize if app is localized

---

## 8. Device Support (iOS)

- Extensions must be **universal** (iPhone + iPad)
- Use Auto Layout and size classes
- Test across devices and orientations

---

## 9. Code Signing

- Must sign containing app **and** all extensions
- All targets signed consistently (same cert family)
- Dev: developer cert / ad hoc
- App Store: distribution cert for all targets

---

## 10. Debugging Workflow

**Key concept:** Debug extension via host app, not containing app.

### Steps

1. Select the **extension scheme**
2. Run → Xcode launches the chosen host app
3. Xcode waits for invocation
4. Trigger the extension in host app UI
5. Debugger attaches, breakpoints hit

### Common Failures

- Running containing app scheme → debugger won't attach to extension
- Invoking from different host app than configured → no attachment

### Enabling for Testing

- Keyboards: enable via Settings → General → Keyboard
- macOS: enable via System Settings

---

## 11. Distribution Rules

- Extensions must be inside a containing app
- Submit containing app to App Store
- Containing app must provide **real user-facing functionality** (not just a shell)
- Extensions cannot be transferred between apps

---

## 12. Architecture Requirements

- Extension targets must include required architectures (arm64 on iOS)
- If containing app links embedded frameworks, app must also include required architectures

---

## Mental Model

```
Host UI → request (context) → extension UI/task → complete/cancel → exit
```

Treat extensions as **ephemeral, memory-constrained, single-purpose**.
