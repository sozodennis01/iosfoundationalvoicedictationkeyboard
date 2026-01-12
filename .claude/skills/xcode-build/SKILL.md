---
description: Build iOS/macOS projects with Xcode. Use when the user asks to build, compile, or check for build errors.
---

# Xcode Build

**⚠️ IMPORTANT: macOS ONLY - Local Execution Required**

This skill ONLY works on the user's local macOS laptop.
- ✅ **DO** use this skill for local, interactive builds
- ❌ **DO NOT** run this in background tasks (they use Linux environments without Xcode)
- ❌ **DO NOT** delegate this to agents that might run in background/remote environments

If you're uncertain about the execution environment, ask the user first.

---

Build projects using `xcodebuild` command-line tool.

## Basic Build Command

```bash
xcodebuild -scheme <SchemeName> -destination '<destination>' build
```

## Common Destinations

- **iOS Simulator**: `platform=iOS Simulator,name=iPhone 16`
- **macOS**: `platform=macOS`
- **Any iOS Device**: `generic/platform=iOS`

## Workflow

1. List available schemes: `xcodebuild -list`
2. Build with appropriate scheme and destination
3. Parse output for errors and warnings
4. Report build status

## Error Handling

- Look for lines starting with `error:` in output
- Check for missing provisioning profiles or signing issues
- Verify scheme name matches exactly (case-sensitive)

## Example

```bash
# List schemes
xcodebuild -list

# Build for iOS Simulator
xcodebuild -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build for release
xcodebuild -scheme MyApp -configuration Release build
```
