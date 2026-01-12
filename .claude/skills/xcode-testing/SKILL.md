---
description: Run Xcode tests for iOS/macOS projects. Use when the user asks to run tests, test a specific file, or check test results.
---

# Xcode Testing

**⚠️ IMPORTANT: macOS ONLY - Local Execution Required**

This skill ONLY works on the user's local macOS laptop.
- ✅ **DO** use this skill for local, interactive test runs
- ❌ **DO NOT** run this in background tasks (they use Linux environments without Xcode)
- ❌ **DO NOT** delegate this to agents that might run in background/remote environments

If you're uncertain about the execution environment, ask the user first.

---

Run tests using `xcodebuild test` command-line tool.

## Basic Test Command

```bash
xcodebuild test -scheme <SchemeName> -destination '<destination>'
```

## Common Destinations

- **iOS Simulator**: `platform=iOS Simulator,name=iPhone 16`
- **macOS**: `platform=macOS`

## Run Specific Tests

```bash
# Run specific test target
xcodebuild test -scheme <Scheme> -only-testing:<TestTarget>

# Run specific test class
xcodebuild test -scheme <Scheme> -only-testing:<TestTarget>/<TestClass>

# Run specific test method
xcodebuild test -scheme <Scheme> -only-testing:<TestTarget>/<TestClass>/<testMethod>
```

## Workflow

1. List available schemes: `xcodebuild -list`
2. Run tests with appropriate scheme and destination
3. Parse output for test results
4. Report pass/fail status and any failures

## Understanding Output

- `Test Suite ... passed` - All tests in suite passed
- `Test Suite ... failed` - One or more tests failed
- `Executed X tests, with Y failures` - Summary at end

## Example

```bash
# Run all tests
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16'

# Run specific test suite
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:MyAppTests

# Run with verbose output
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16' | xcpretty
```
